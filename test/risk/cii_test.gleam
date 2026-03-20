import gleeunit
import gleeunit/should
import zeitgeist/risk/cii

pub fn main() {
  gleeunit.main()
}

pub fn initial_score_test() {
  let risk = cii.new("SY")
  risk.cii_score |> should.equal(0.0)
}

pub fn compute_event_score_test() {
  let components =
    cii.CiiComponents(
      conflict: 80.0,
      unrest: 60.0,
      security: 40.0,
      information: 50.0,
    )
  let score = cii.event_score(components)
  let assert True = score >. 59.4
  let assert True = score <. 59.6
}

pub fn floor_active_war_test() {
  let risk = cii.new("UA") |> cii.set_floor(70.0) |> cii.update_score(30.0)
  let assert True = risk.cii_score >=. 70.0
}

pub fn compute_full_cii_test() {
  let score = cii.compute_cii(45.0, 80.0, 0.0)
  let assert True = score >. 65.9
  let assert True = score <. 66.1
}
