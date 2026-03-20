import gleeunit
import gleeunit/should
import zeitgeist/core/entity
import zeitgeist/core/event
import zeitgeist/risk/correlation

pub fn main() {
  gleeunit.main()
}

pub fn velocity_spike_detected_test() {
  correlation.check_velocity_spike(15.0, 4.0, 3.0) |> should.equal(True)
}

pub fn velocity_spike_not_detected_test() {
  correlation.check_velocity_spike(5.0, 4.0, 3.0) |> should.equal(False)
}

pub fn velocity_spike_zero_baseline_test() {
  correlation.check_velocity_spike(100.0, 0.0, 3.0) |> should.equal(False)
}

pub fn triangulation_detected_test() {
  let iran = entity.EntityRef(id: "iran", kind: entity.Government, name: "Iran")

  let news_event =
    event.Event(
      ..event.new(
        "e1",
        event.NewsArticle(
          title: "Iran",
          summary: "conflict",
          category: event.Conflict,
        ),
      ),
      entities: [iran],
      timestamp: 1000,
    )

  let military_event =
    event.Event(
      ..event.new(
        "e2",
        event.MilitaryTrack(
          track_type: event.Aircraft,
          callsign: "IR001",
          heading: 270.0,
        ),
      ),
      entities: [iran],
      timestamp: 1001,
    )

  let market_event =
    event.Event(
      ..event.new(
        "e3",
        event.MarketTick(symbol: "OIL", price: 95.0, change_pct: 4.2),
      ),
      entities: [iran],
      timestamp: 1002,
    )

  let events = [news_event, military_event, market_event]
  correlation.check_triangulation(events, "iran", 3) |> should.equal(True)
}

pub fn triangulation_not_detected_test() {
  let iran = entity.EntityRef(id: "iran", kind: entity.Government, name: "Iran")

  let news1 =
    event.Event(
      ..event.new(
        "e1",
        event.NewsArticle(
          title: "Iran strikes",
          summary: "military action",
          category: event.Conflict,
        ),
      ),
      entities: [iran],
      timestamp: 1000,
    )

  let news2 =
    event.Event(
      ..event.new(
        "e2",
        event.NewsArticle(
          title: "Iran tensions",
          summary: "politics",
          category: event.Politics,
        ),
      ),
      entities: [iran],
      timestamp: 1001,
    )

  // only 1 unique stream (NewsStream), need 3
  let events = [news1, news2]
  correlation.check_triangulation(events, "iran", 3) |> should.equal(False)
}

pub fn news_leads_market_detected_test() {
  // news at 1000ms, market at 2_400_000ms → lag = 2_399_000ms ≈ 39.98 min, within 15-60 min
  correlation.check_news_leads_market(1000, 2_400_000, 15, 60)
  |> should.equal(True)
}

pub fn news_leads_market_too_fast_test() {
  // news at 1000ms, market at 301_000ms → lag = 300_000ms = 5 min, below 15 min min
  correlation.check_news_leads_market(1000, 301_000, 15, 60)
  |> should.equal(False)
}

pub fn military_surge_detected_test() {
  correlation.check_military_surge(3.5, 3.0) |> should.equal(True)
}

pub fn military_surge_not_detected_test() {
  correlation.check_military_surge(2.0, 3.0) |> should.equal(False)
}

pub fn prediction_leads_news_detected_test() {
  // prediction at 0ms, news at 1_800_000ms → lag = 30 min, within 15-60 min
  correlation.check_prediction_leads_news(0, 1_800_000, 15, 60)
  |> should.equal(True)
}

pub fn prediction_leads_news_too_late_test() {
  // prediction at 0ms, news at 5_000_000ms → lag = ~83 min, exceeds 60 min max
  correlation.check_prediction_leads_news(0, 5_000_000, 15, 60)
  |> should.equal(False)
}

pub fn prediction_leads_news_too_early_test() {
  // prediction at 0ms, news at 300_000ms → lag = 5 min, below 15 min min
  correlation.check_prediction_leads_news(0, 300_000, 15, 60)
  |> should.equal(False)
}

pub fn silent_divergence_detected_test() {
  // CII spiked from 20 to 35 (delta=15 >= threshold=10), market barely moved (0.5%)
  correlation.check_silent_divergence(35.0, 20.0, 0.5, 10.0)
  |> should.equal(True)
}

pub fn silent_divergence_not_detected_market_moved_test() {
  // CII spiked but market also moved significantly (3.5%)
  correlation.check_silent_divergence(35.0, 20.0, 3.5, 10.0)
  |> should.equal(False)
}

pub fn silent_divergence_not_detected_small_spike_test() {
  // CII delta only 5 (below threshold 10), market barely moved
  correlation.check_silent_divergence(25.0, 20.0, 0.5, 10.0)
  |> should.equal(False)
}
