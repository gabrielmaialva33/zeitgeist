import gleam/float
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
      let has_entity = list.any(evt.entities, fn(ref) { ref.id == entity_id })
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

/// Returns True when a prediction was made before the news confirmed it,
/// with a lag within [min_lag_min, max_lag_min].
pub fn check_prediction_leads_news(
  pred_ts: Int,
  news_ts: Int,
  min_lag_min: Int,
  max_lag_min: Int,
) -> Bool {
  let lag_ms = news_ts - pred_ts
  lag_ms >= min_lag_min * 60_000 && lag_ms <= max_lag_min * 60_000
}

/// Returns True when CII spiked significantly (delta >= threshold)
/// but the market barely moved (abs change < 2.0%), indicating silent divergence.
pub fn check_silent_divergence(
  cii_score: Float,
  cii_baseline: Float,
  market_change_pct: Float,
  threshold: Float,
) -> Bool {
  let delta = cii_score -. cii_baseline
  let abs_market = case market_change_pct <. 0.0 {
    True -> 0.0 -. market_change_pct
    False -> market_change_pct
  }
  delta >=. threshold && abs_market <. 2.0
}

/// Returns True if infra disruption > threshold AND |market_change| > 1.0,
/// indicating a cascade trigger between infrastructure and market.
pub fn check_cascade_trigger(
  infra_disruption: Float,
  market_change_pct: Float,
  threshold: Float,
) -> Bool {
  infra_disruption >. threshold
  && float.absolute_value(market_change_pct) >. 1.0
}

/// Returns True when market moved before news, with lag in [min_lag_min, max_lag_min].
pub fn check_market_leads_news(
  market_ts: Int,
  news_ts: Int,
  min_lag_min: Int,
  max_lag_min: Int,
) -> Bool {
  let lag_ms = news_ts - market_ts
  lag_ms >= min_lag_min * 60_000 && lag_ms <= max_lag_min * 60_000
}

/// Returns True when diplomatic message volume is at least baseline * multiplier.
pub fn check_diplomatic_surge(
  message_count: Int,
  baseline: Int,
  multiplier: Float,
) -> Bool {
  int_to_float(message_count) >=. int_to_float(baseline) *. multiplier
}

/// Returns True when region_count meets or exceeds min_regions.
pub fn check_multi_region_convergence(
  region_count: Int,
  min_regions: Int,
) -> Bool {
  region_count >= min_regions
}

/// Returns True when sentiment acceleration (curr_delta - prev_delta) exceeds threshold.
pub fn check_sentiment_momentum(
  prev_delta: Float,
  curr_delta: Float,
  threshold: Float,
) -> Bool {
  let acceleration = curr_delta -. prev_delta
  acceleration >. threshold
}

/// Returns True when all three disruption conditions are met simultaneously.
pub fn check_supply_chain_disruption(
  infra_disrupted: Bool,
  trade_affected: Bool,
  market_drop_pct: Float,
  threshold: Float,
) -> Bool {
  infra_disrupted && trade_affected && market_drop_pct >. threshold
}

/// Returns True when activity_count meets or exceeds baseline * 2 for the given theater.
pub fn check_theater_escalation(
  activity_count: Int,
  baseline: Int,
  _theater: String,
) -> Bool {
  int_to_float(activity_count) >=. int_to_float(baseline) *. 2.0
}

/// Returns True when current_mentions >= baseline_mentions * multiplier.
pub fn check_entity_frequency_spike(
  current_mentions: Int,
  baseline_mentions: Int,
  multiplier: Float,
) -> Bool {
  int_to_float(current_mentions) >=. int_to_float(baseline_mentions) *. multiplier
}

@external(erlang, "erlang", "float")
fn int_to_float(n: Int) -> Float
