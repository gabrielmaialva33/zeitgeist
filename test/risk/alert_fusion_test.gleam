import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import zeitgeist/core/geo.{GeoPoint}
import zeitgeist/risk/alert_fusion

pub fn main() {
  gleeunit.main()
}

pub fn create_signal_test() {
  let sig =
    alert_fusion.new_signal(
      "s1",
      "military",
      "IR",
      None,
      0.8,
      1_000_000,
    )
  sig.id |> should.equal("s1")
  sig.signal_type |> should.equal("military")
  sig.country |> should.equal("IR")
  sig.severity |> should.equal(0.8)
  sig.timestamp |> should.equal(1_000_000)
}

pub fn merge_nearby_same_country_test() {
  let a =
    alert_fusion.new_signal(
      "a1",
      "military",
      "IR",
      Some(GeoPoint(lat: 26.0, lon: 56.0)),
      0.9,
      1_000_000,
    )
  let b =
    alert_fusion.new_signal(
      "b1",
      "economic",
      "IR",
      Some(GeoPoint(lat: 26.1, lon: 56.1)),
      0.8,
      1_010_000,
    )

  let result = alert_fusion.try_merge(a, b, 50.0, 60_000)
  let assert Ok(fused) = result
  fused.country |> should.equal("IR")
  let assert True = fused.convergence_score >. 0.0
}

pub fn no_merge_distant_signals_test() {
  // Tokyo vs Damascus — thousands of km apart
  let a =
    alert_fusion.new_signal(
      "a2",
      "military",
      "JP",
      Some(GeoPoint(lat: 35.68, lon: 139.69)),
      0.9,
      1_000_000,
    )
  let b =
    alert_fusion.new_signal(
      "b2",
      "military",
      "SY",
      Some(GeoPoint(lat: 33.51, lon: 36.29)),
      0.9,
      1_005_000,
    )

  let result = alert_fusion.try_merge(a, b, 100.0, 60_000)
  result |> should.equal(Error(Nil))
}

pub fn no_merge_time_too_far_test() {
  let a =
    alert_fusion.new_signal("a3", "military", "IR", None, 0.8, 1_000_000)
  let b =
    alert_fusion.new_signal("b3", "military", "IR", None, 0.8, 2_000_000)

  // max_time_ms = 30_000, diff = 1_000_000
  let result = alert_fusion.try_merge(a, b, 500.0, 30_000)
  result |> should.equal(Error(Nil))
}

pub fn convergence_score_three_types_test() {
  let signals = [
    alert_fusion.new_signal("s1", "military", "IR", None, 0.9, 1_000_000),
    alert_fusion.new_signal("s2", "economic", "IR", None, 0.8, 1_001_000),
    alert_fusion.new_signal("s3", "cyber", "IR", None, 0.5, 1_002_000),
  ]

  let score = alert_fusion.country_convergence_score(signals)
  // type_bonus = 3 * 20 = 60
  // count_bonus = min(30, 3 * 5) = 15
  // severity_bonus = 2 * 10 = 20 (s1 and s2 > 0.7)
  // total = 95, capped at 100
  let assert True = score >. 94.9
  let assert True = score <=. 100.0
}

pub fn strategic_composite_score_test() {
  // convergence=80, cii=60, infra=40, theater_boost=5, breaking_boost=3
  // = 80*0.30 + 60*0.50 + 40*0.20 + 5 + 3
  // = 24 + 30 + 8 + 5 + 3 = 70
  let score = alert_fusion.strategic_risk_score(80.0, 60.0, 40.0, 5.0, 3.0)
  let assert True = score >. 69.9
  let assert True = score <. 70.1
}

pub fn strategic_score_capped_at_100_test() {
  let score =
    alert_fusion.strategic_risk_score(100.0, 100.0, 100.0, 20.0, 20.0)
  score |> should.equal(100.0)
}

pub fn merge_no_location_same_country_test() {
  // No GeoPoints — falls back to country match
  let a =
    alert_fusion.new_signal("a4", "military", "UA", None, 0.9, 1_000_000)
  let b =
    alert_fusion.new_signal("b4", "cyber", "UA", None, 0.8, 1_005_000)

  let result = alert_fusion.try_merge(a, b, 999.0, 60_000)
  let assert Ok(fused) = result
  fused.country |> should.equal("UA")
}

pub fn merge_no_location_different_country_fails_test() {
  let a =
    alert_fusion.new_signal("a5", "military", "UA", None, 0.9, 1_000_000)
  let b =
    alert_fusion.new_signal("b5", "military", "RU", None, 0.9, 1_005_000)

  let result = alert_fusion.try_merge(a, b, 999.0, 60_000)
  result |> should.equal(Error(Nil))
}
