import gleam/float

pub type CountryRisk {
  CountryRisk(
    country_code: String,
    cii_score: Float,
    components: CiiComponents,
    trend: Trend,
    floor: Float,
    last_updated: Int,
  )
}

pub type CiiComponents {
  CiiComponents(conflict: Float, unrest: Float, security: Float, information: Float)
}

pub type Trend {
  Rising
  Stable
  Falling
}

pub fn new(country_code: String) -> CountryRisk {
  CountryRisk(
    country_code: country_code,
    cii_score: 0.0,
    components: CiiComponents(
      conflict: 0.0,
      unrest: 0.0,
      security: 0.0,
      information: 0.0,
    ),
    trend: Stable,
    floor: 0.0,
    last_updated: 0,
  )
}

pub fn set_floor(risk: CountryRisk, floor: Float) -> CountryRisk {
  CountryRisk(..risk, floor: floor)
}

pub fn event_score(c: CiiComponents) -> Float {
  c.conflict *. 0.30 +. c.unrest *. 0.25 +. c.security *. 0.20
  +. c.information *. 0.25
}

pub fn compute_cii(baseline_risk: Float, evt_score: Float, floor: Float) -> Float {
  let raw = baseline_risk *. 0.4 +. evt_score *. 0.6
  float.max(floor, float.min(100.0, raw))
}

pub fn update_score(risk: CountryRisk, evt_score: Float) -> CountryRisk {
  let new_score = compute_cii(risk.cii_score, evt_score, risk.floor)
  let new_trend = case new_score >. risk.cii_score {
    True -> Rising
    False ->
      case new_score <. risk.cii_score {
        True -> Falling
        False -> Stable
      }
  }
  CountryRisk(..risk, cii_score: new_score, trend: new_trend)
}
