import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import zeitgeist/core/event
import zeitgeist/predict/scenario
import zeitgeist/predict/validator

pub fn main() {
  gleeunit.main()
}

pub fn new_scenario_is_active_test() {
  let s =
    scenario.new(
      "s1",
      "w1",
      scenario.ConflictEscalation(region: "ME", from_level: 2, to_level: 4),
      0.7,
      48,
    )
  s.status |> should.equal(scenario.Active)
  s.id |> should.equal("s1")
  s.world_id |> should.equal("w1")
  s.confidence |> should.equal(0.7)
  s.horizon_hours |> should.equal(48)
}

pub fn expired_scenario_test() {
  let s =
    scenario.new(
      "s2",
      "w1",
      scenario.ConflictEscalation(region: "EU", from_level: 1, to_level: 3),
      0.5,
      24,
    )
  // created_at=0, check at 100_000_000ms (way past 24h horizon)
  let s_with_zero = scenario.Scenario(..s, created_at: 0)
  let result = scenario.check_expiry(s_with_zero, 100_000_000)
  result.status |> should.equal(scenario.Expired)
}

pub fn validate_conflict_match_test() {
  let s =
    scenario.new(
      "s3",
      "w1",
      scenario.ConflictEscalation(region: "ME", from_level: 2, to_level: 4),
      0.7,
      48,
    )
  let evt =
    event.Event(
      ..event.new(
        "e1",
        event.NewsArticle(
          title: "Conflict escalating in ME region",
          summary: "tensions rising",
          category: event.Conflict,
        ),
      ),
      timestamp: 1000,
    )
  let result = validator.check_prediction(s, evt)
  result |> should.equal(Some(scenario.ConfirmedOutcome(accuracy: 1.0, lag_hours: 0.0)))
}

pub fn validate_conflict_no_match_test() {
  let s =
    scenario.new(
      "s4",
      "w1",
      scenario.ConflictEscalation(region: "ME", from_level: 2, to_level: 4),
      0.7,
      48,
    )
  let evt =
    event.Event(
      ..event.new(
        "e2",
        event.NewsArticle(
          title: "Trade deal signed in Asia",
          summary: "economic news",
          category: event.Economy,
        ),
      ),
      timestamp: 1000,
    )
  let result = validator.check_prediction(s, evt)
  result |> should.equal(None)
}

pub fn validate_market_move_up_test() {
  let s =
    scenario.new(
      "s5",
      "w1",
      scenario.MarketMove(symbol: "OIL", direction: scenario.Up, magnitude_pct: 5.0),
      0.6,
      12,
    )
  let evt =
    event.Event(
      ..event.new(
        "e3",
        event.MarketTick(symbol: "OIL", price: 100.0, change_pct: 3.2),
      ),
      timestamp: 2000,
    )
  let result = validator.check_prediction(s, evt)
  result |> should.equal(Some(scenario.ConfirmedOutcome(accuracy: 1.0, lag_hours: 0.0)))
}

pub fn validate_market_move_direction_mismatch_test() {
  let s =
    scenario.new(
      "s6",
      "w1",
      scenario.MarketMove(symbol: "OIL", direction: scenario.Up, magnitude_pct: 5.0),
      0.6,
      12,
    )
  let evt =
    event.Event(
      ..event.new(
        "e4",
        event.MarketTick(symbol: "OIL", price: 90.0, change_pct: -2.1),
      ),
      timestamp: 3000,
    )
  let result = validator.check_prediction(s, evt)
  result
  |> should.equal(Some(scenario.PartialMatch(accuracy: 0.5, deviation: "direction mismatch")))
}
