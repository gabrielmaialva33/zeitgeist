import gleeunit
import gleeunit/should
import zeitgeist/core/entity
import zeitgeist/graph/decay

pub fn main() {
  gleeunit.main()
}

pub fn default_profile_test() {
  let p = decay.profile_for(entity.Hostile)
  p.half_life_hours |> should.equal(168.0)
  p.floor |> should.equal(0.2)
}

pub fn geopolitical_persists_longer_test() {
  let hostile = decay.profile_for(entity.Hostile)
  let default = decay.default_profile()
  let assert True = hostile.half_life_hours >. default.half_life_hours
}

pub fn weight_at_zero_age_test() {
  let w = decay.compute_weight(0.9, 0.0, decay.default_profile(), 1.0)
  let assert True = w >. 0.89
  let assert True = w <. 0.91
}

pub fn weight_at_half_life_test() {
  let profile =
    decay.DecayProfile(half_life_hours: 48.0, floor: 0.0, context_boost: 1.0)
  let w = decay.compute_weight(1.0, 48.0, profile, 1.0)
  let assert True = w >. 0.49
  let assert True = w <. 0.51
}

pub fn weight_never_below_floor_test() {
  let profile =
    decay.DecayProfile(half_life_hours: 1.0, floor: 0.2, context_boost: 1.0)
  let w = decay.compute_weight(1.0, 1000.0, profile, 1.0)
  w |> should.equal(0.2)
}
