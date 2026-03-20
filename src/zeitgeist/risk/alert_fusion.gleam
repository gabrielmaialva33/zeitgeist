import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, Some}
import gleam/set
import zeitgeist/core/geo.{type GeoPoint, haversine_km}

pub type GeoSignal {
  GeoSignal(
    id: String,
    signal_type: String,
    country: String,
    location: Option(GeoPoint),
    severity: Float,
    timestamp: Int,
  )
}

pub type FusedAlert {
  FusedAlert(
    signals: List(GeoSignal),
    convergence_score: Float,
    country: String,
    timestamp: Int,
  )
}

pub fn new_signal(
  id: String,
  signal_type: String,
  country: String,
  location: Option(GeoPoint),
  severity: Float,
  timestamp: Int,
) -> GeoSignal {
  GeoSignal(
    id: id,
    signal_type: signal_type,
    country: country,
    location: location,
    severity: severity,
    timestamp: timestamp,
  )
}

fn abs_int(n: Int) -> Int {
  case n < 0 {
    True -> 0 - n
    False -> n
  }
}

fn within_space(
  a: GeoSignal,
  b: GeoSignal,
  max_distance_km: Float,
) -> Bool {
  case a.location, b.location {
    Some(loc_a), Some(loc_b) ->
      haversine_km(loc_a, loc_b) <=. max_distance_km
    _, _ -> a.country == b.country
  }
}

pub fn try_merge(
  a: GeoSignal,
  b: GeoSignal,
  max_distance_km: Float,
  max_time_ms: Int,
) -> Result(FusedAlert, Nil) {
  let time_diff = abs_int(a.timestamp - b.timestamp)
  case time_diff <= max_time_ms && within_space(a, b, max_distance_km) {
    False -> Error(Nil)
    True -> {
      let signals = [a, b]
      let score = country_convergence_score(signals)
      let ts = case a.timestamp <= b.timestamp {
        True -> a.timestamp
        False -> b.timestamp
      }
      Ok(FusedAlert(
        signals: signals,
        convergence_score: score,
        country: a.country,
        timestamp: ts,
      ))
    }
  }
}

pub fn country_convergence_score(signals: List(GeoSignal)) -> Float {
  let count = list.length(signals)
  let types = list.map(signals, fn(s) { s.signal_type })
  let unique_types = set.from_list(types)
  let distinct = set.size(unique_types)

  let type_bonus = int.to_float(distinct * 20)
  let count_bonus = float.min(30.0, int.to_float(count * 5))
  let high_sev = list.count(signals, fn(s) { s.severity >. 0.7 })
  let severity_bonus = int.to_float(high_sev * 10)

  float.min(100.0, type_bonus +. count_bonus +. severity_bonus)
}

pub fn strategic_risk_score(
  convergence: Float,
  cii: Float,
  infra_impact: Float,
  theater_boost: Float,
  breaking_boost: Float,
) -> Float {
  let raw =
    convergence
    *. 0.30
    +. cii
    *. 0.50
    +. infra_impact
    *. 0.20
    +. theater_boost
    +. breaking_boost
  float.min(100.0, raw)
}
