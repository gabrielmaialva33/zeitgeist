import gleam/float
import zeitgeist/core/entity.{type RelationKind}

pub type DecayProfile {
  DecayProfile(half_life_hours: Float, floor: Float, context_boost: Float)
}

pub fn default_profile() -> DecayProfile {
  DecayProfile(half_life_hours: 48.0, floor: 0.05, context_boost: 1.0)
}

pub fn profile_for(relation: RelationKind) -> DecayProfile {
  case relation {
    entity.Hostile | entity.Allied ->
      DecayProfile(half_life_hours: 168.0, floor: 0.2, context_boost: 1.5)
    entity.TradePartner ->
      DecayProfile(half_life_hours: 720.0, floor: 0.1, context_boost: 1.0)
    entity.LocatedIn ->
      DecayProfile(half_life_hours: 8760.0, floor: 0.5, context_boost: 1.0)
    _ -> default_profile()
  }
}

pub fn compute_weight(
  confidence: Float,
  age_hours: Float,
  profile: DecayProfile,
  context_boost_multiplier: Float,
) -> Float {
  let lambda = ln2() /. profile.half_life_hours
  let decay_factor = exp(float.negate(lambda *. age_hours))
  let raw =
    confidence *. decay_factor *. profile.context_boost
    *. context_boost_multiplier
  float.max(profile.floor, raw)
}

@external(erlang, "math", "exp")
fn exp(x: Float) -> Float

fn ln2() -> Float {
  0.6931471805599453
}
