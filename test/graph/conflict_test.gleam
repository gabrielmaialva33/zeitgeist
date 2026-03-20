import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/core/entity
import zeitgeist/graph/conflict
import zeitgeist/graph/fact.{type AtomicFact, AtomicFact}

pub fn main() {
  gleeunit.main()
}

fn make_fact(
  id: String,
  confidence: Float,
  credibility: Float,
  observed_at: Int,
  frequency: Int,
) -> AtomicFact {
  AtomicFact(
    id: id,
    subject: "entity_a",
    predicate: entity.Allied,
    object: "entity_b",
    observed_at: observed_at,
    valid_from: observed_at,
    valid_until: None,
    confidence: confidence,
    source_credibility: credibility,
    frequency: frequency,
  )
}

pub fn higher_confidence_wins_test() {
  let existing = make_fact("f1", 0.5, 0.8, 1000, 1)
  let incoming = make_fact("f2", 0.9, 0.8, 2000, 1)
  case conflict.resolve(existing, incoming, 2000) {
    conflict.Supersede(..) -> should.be_ok(Ok(Nil))
    _ -> should.fail()
  }
}

pub fn more_recent_gets_boost_test() {
  let existing = make_fact("f1", 0.8, 0.8, 0, 1)
  let incoming = make_fact("f2", 0.8, 0.8, 100_000, 1)
  case conflict.resolve(existing, incoming, 100_000) {
    conflict.Supersede(..) -> should.be_ok(Ok(Nil))
    _ -> should.fail()
  }
}

pub fn higher_frequency_wins_test() {
  let existing = make_fact("f1", 0.7, 0.8, 1000, 5)
  let incoming = make_fact("f2", 0.7, 0.8, 1000, 1)
  case conflict.resolve(existing, incoming, 1000) {
    conflict.Reject(..) -> should.be_ok(Ok(Nil))
    _ -> should.fail()
  }
}
