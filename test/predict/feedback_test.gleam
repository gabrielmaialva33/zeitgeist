import gleam/erlang/process
import gleam/list
import gleeunit
import gleeunit/should
import zeitgeist/core/event
import zeitgeist/predict/feedback
import zeitgeist/predict/scenario

pub fn main() {
  gleeunit.main()
}

pub fn add_and_list_test() {
  let assert Ok(fb) = feedback.start()

  let s1 =
    scenario.new(
      "s1",
      "w1",
      scenario.ConflictEscalation(region: "ME", from_level: 2, to_level: 4),
      0.7,
      48,
    )
  let s2 =
    scenario.new(
      "s2",
      "w1",
      scenario.MarketMove(
        symbol: "OIL",
        direction: scenario.Up,
        magnitude_pct: 5.0,
      ),
      0.6,
      12,
    )

  feedback.add_prediction(fb, s1)
  feedback.add_prediction(fb, s2)
  process.sleep(20)

  let active = feedback.list_active(fb)
  list.length(active) |> should.equal(2)

  feedback.stop(fb)
}

pub fn initial_stats_zero_test() {
  let assert Ok(fb) = feedback.start()

  let stats = feedback.get_stats(fb)
  stats.active |> should.equal(0)
  stats.checked |> should.equal(0)
  stats.confirmed |> should.equal(0)
  stats.refuted |> should.equal(0)
  stats.expired |> should.equal(0)

  feedback.stop(fb)
}

pub fn validate_confirms_prediction_test() {
  let assert Ok(fb) = feedback.start()

  let s =
    scenario.new(
      "s3",
      "w1",
      scenario.ConflictEscalation(region: "ME", from_level: 2, to_level: 4),
      0.7,
      48,
    )
  feedback.add_prediction(fb, s)

  // Event that matches the prediction (contains region "ME" in title)
  let evt =
    event.Event(
      ..event.new(
        "e1",
        event.NewsArticle(
          title: "Conflict escalating in ME",
          summary: "tensions rising",
          category: event.Conflict,
        ),
      ),
      timestamp: 1000,
    )

  feedback.check_event(fb, evt)
  process.sleep(50)

  let active = feedback.list_active(fb)
  // Prediction should be confirmed, no longer active
  list.length(active) |> should.equal(0)

  let stats = feedback.get_stats(fb)
  stats.confirmed |> should.equal(1)
  stats.checked |> should.equal(1)
  stats.active |> should.equal(0)

  feedback.stop(fb)
}

pub fn check_event_no_match_keeps_active_test() {
  let assert Ok(fb) = feedback.start()

  let s =
    scenario.new(
      "s4",
      "w1",
      scenario.ConflictEscalation(region: "EU", from_level: 1, to_level: 3),
      0.5,
      24,
    )
  feedback.add_prediction(fb, s)

  let evt =
    event.Event(
      ..event.new(
        "e2",
        event.NewsArticle(
          title: "Trade deal signed in Asia",
          summary: "economy",
          category: event.Economy,
        ),
      ),
      timestamp: 2000,
    )

  feedback.check_event(fb, evt)
  process.sleep(50)

  // No match → still active
  let active = feedback.list_active(fb)
  list.length(active) |> should.equal(1)

  let stats = feedback.get_stats(fb)
  stats.confirmed |> should.equal(0)
  stats.checked |> should.equal(0)

  feedback.stop(fb)
}
