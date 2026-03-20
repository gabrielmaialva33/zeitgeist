import gleeunit
import gleeunit/should
import zeitgeist/risk/anomaly

pub fn main() {
  gleeunit.main()
}

pub fn new_detector_has_zero_count_test() {
  let d = anomaly.new_detector("price_vol")
  d.count |> should.equal(0)
}

pub fn add_samples_updates_stats_test() {
  let d =
    anomaly.new_detector("test")
    |> anomaly.add_sample(10.0)
    |> anomaly.add_sample(11.0)
    |> anomaly.add_sample(12.0)

  d.count |> should.equal(3)
  let assert True = d.mean >. 10.9
  let assert True = d.mean <. 11.1
}

pub fn z_score_normal_value_test() {
  let d =
    [10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 11.0, 10.0, 10.0]
    |> list_fold_detector("seg")

  let z = anomaly.z_score(d, 10.5)
  let assert True = z <. 2.0
}

pub fn z_score_anomalous_value_test() {
  // use samples with variance so std > 0; mean ~10, std ~1
  let d =
    [9.0, 10.0, 11.0, 10.0, 9.0, 11.0, 10.0, 9.0, 11.0, 10.0]
    |> list_fold_detector("seg")

  // 40.0 is ~30 std devs from the mean → well above 3.0
  let z = anomaly.z_score(d, 40.0)
  let assert True = z >. 3.0
}

pub fn cold_start_returns_zero_test() {
  let d =
    anomaly.new_detector("cold")
    |> anomaly.add_sample(100.0)
    |> anomaly.add_sample(200.0)

  anomaly.z_score(d, 999.0) |> should.equal(0.0)
}

pub fn classify_normal_test() {
  anomaly.classify(1.5) |> should.equal(anomaly.Normal)
}

pub fn classify_elevated_test() {
  anomaly.classify(2.5) |> should.equal(anomaly.Elevated)
}

pub fn classify_critical_test() {
  anomaly.classify(3.5) |> should.equal(anomaly.Critical)
}

pub fn classify_extreme_test() {
  anomaly.classify(4.5) |> should.equal(anomaly.ExtremeAnomaly)
}

// helper: fold a list of floats into a detector
fn list_fold_detector(
  values: List(Float),
  segment: String,
) -> anomaly.WelfordDetector {
  let d = anomaly.new_detector(segment)
  fold_samples(d, values)
}

fn fold_samples(
  d: anomaly.WelfordDetector,
  values: List(Float),
) -> anomaly.WelfordDetector {
  case values {
    [] -> d
    [v, ..rest] -> fold_samples(anomaly.add_sample(d, v), rest)
  }
}
