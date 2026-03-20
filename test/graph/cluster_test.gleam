import gleam/list
import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/core/entity
import zeitgeist/graph/cluster
import zeitgeist/graph/fact.{type AtomicFact, AtomicFact}

pub fn main() {
  gleeunit.main()
}

// Helper: make a fact with observed_at = now (within window)
fn make_fact(
  id: String,
  subject: String,
  now_ms: Int,
  confidence: Float,
) -> AtomicFact {
  AtomicFact(
    id: id,
    subject: subject,
    predicate: entity.Allied,
    object: "other",
    observed_at: now_ms,
    valid_from: now_ms,
    valid_until: None,
    confidence: confidence,
    source_credibility: 0.9,
    frequency: 1,
  )
}

pub fn entity_with_3_relations_detected_test() {
  let now = 1_000_000_000
  let window = 3_600_000
  let facts = [
    make_fact("f1", "usa", now, 0.9),
    make_fact("f2", "usa", now - 100, 0.8),
    make_fact("f3", "usa", now - 200, 0.7),
  ]
  let clusters = cluster.detect(facts, now, window, 3)
  list.length(clusters) |> should.equal(1)
  let assert [c] = clusters
  c.entity_id |> should.equal("usa")
  c.new_relations |> should.equal(3)
  // avg_confidence = (0.9 + 0.8 + 0.7) / 3 = 0.8
  let assert True = c.avg_confidence >. 0.79
  let assert True = c.avg_confidence <. 0.81
}

pub fn entity_below_threshold_not_detected_test() {
  let now = 1_000_000_000
  let window = 3_600_000
  let facts = [
    make_fact("f1", "china", now, 0.8),
    make_fact("f2", "china", now - 100, 0.7),
  ]
  // min 3 relations, china only has 2
  let clusters = cluster.detect(facts, now, window, 3)
  list.length(clusters) |> should.equal(0)
}

pub fn multiple_entities_test() {
  let now = 1_000_000_000
  let window = 3_600_000
  let facts = [
    make_fact("f1", "usa", now, 0.9),
    make_fact("f2", "usa", now - 100, 0.8),
    make_fact("f3", "usa", now - 200, 0.7),
    make_fact("f4", "ru", now, 0.6),
    make_fact("f5", "ru", now - 50, 0.5),
    make_fact("f6", "ru", now - 150, 0.4),
    // china: only 2, should not appear
    make_fact("f7", "china", now, 0.9),
    make_fact("f8", "china", now - 100, 0.8),
  ]
  let clusters = cluster.detect(facts, now, window, 3)
  list.length(clusters) |> should.equal(2)
  let ids = list.map(clusters, fn(c) { c.entity_id })
  let assert True = list.contains(ids, "usa")
  let assert True = list.contains(ids, "ru")
}

pub fn old_facts_outside_window_ignored_test() {
  let now = 1_000_000_000
  let window = 3_600_000
  // 2 fresh, 1 old (outside window)
  let facts = [
    make_fact("f1", "usa", now, 0.9),
    make_fact("f2", "usa", now - 100, 0.8),
    // this is old: now - window - 1 is outside
    AtomicFact(
      id: "f_old",
      subject: "usa",
      predicate: entity.Allied,
      object: "other",
      observed_at: now - window - 1,
      valid_from: 0,
      valid_until: None,
      confidence: 0.9,
      source_credibility: 0.9,
      frequency: 1,
    ),
  ]
  // min 3: usa only has 2 within window
  let clusters = cluster.detect(facts, now, window, 3)
  list.length(clusters) |> should.equal(0)
}
