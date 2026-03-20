import gleam/list
import gleam/set
import zeitgeist/core/event.{type Event, type EventStream}

pub fn check_velocity_spike(
  current_rate: Float,
  baseline_rate: Float,
  threshold_multiplier: Float,
) -> Bool {
  baseline_rate >. 0.0 && current_rate >=. baseline_rate *. threshold_multiplier
}

pub fn check_triangulation(
  events: List(Event),
  entity_id: String,
  min_streams: Int,
) -> Bool {
  let streams =
    list.filter_map(events, fn(evt) {
      let has_entity =
        list.any(evt.entities, fn(ref) { ref.id == entity_id })
      case has_entity {
        True -> Ok(event.stream_from_kind(evt.kind))
        False -> Error(Nil)
      }
    })

  let unique_streams: set.Set(EventStream) = set.from_list(streams)
  set.size(unique_streams) >= min_streams
}

pub fn check_news_leads_market(
  news_ts: Int,
  market_ts: Int,
  min_lag_minutes: Int,
  max_lag_minutes: Int,
) -> Bool {
  let lag_ms = market_ts - news_ts
  lag_ms >= min_lag_minutes * 60_000 && lag_ms <= max_lag_minutes * 60_000
}

pub fn check_military_surge(z_score: Float, threshold: Float) -> Bool {
  z_score >=. threshold
}
