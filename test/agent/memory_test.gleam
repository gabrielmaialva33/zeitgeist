import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/agent/memory
import zeitgeist/core/entity
import zeitgeist/graph/fact.{type AtomicFact, AtomicFact}
import zeitgeist/agent/action.{DoNothing}

pub fn main() {
  gleeunit.main()
}

fn make_fact(id: String) -> AtomicFact {
  AtomicFact(
    id: id,
    subject: "usa",
    predicate: entity.Hostile,
    object: "russia",
    observed_at: 1_000_000,
    valid_from: 1_000_000,
    valid_until: None,
    confidence: 0.9,
    source_credibility: 0.8,
    frequency: 1,
  )
}

pub fn new_memory_empty_test() {
  let mem = memory.new(50)
  memory.fact_count(mem) |> should.equal(0)
  memory.sentiment(mem) |> should.equal(0.0)
}

pub fn add_fact_test() {
  let mem = memory.new(50) |> memory.add_fact(make_fact("f1"))
  memory.fact_count(mem) |> should.equal(1)
}

pub fn memory_cap_enforced_test() {
  let mem =
    memory.new(3)
    |> memory.add_fact(make_fact("f1"))
    |> memory.add_fact(make_fact("f2"))
    |> memory.add_fact(make_fact("f3"))
    |> memory.add_fact(make_fact("f4"))
    |> memory.add_fact(make_fact("f5"))
  memory.fact_count(mem) |> should.equal(3)
}

pub fn record_action_test() {
  let mem = memory.new(50) |> memory.record_action(1, DoNothing)
  memory.action_count(mem) |> should.equal(1)
}

pub fn update_sentiment_test() {
  let mem =
    memory.new(50)
    |> memory.adjust_sentiment(0.3)
    |> memory.adjust_sentiment(-0.5)
  // 0.0 + 0.3 - 0.5 = -0.2, clamped to [-1, 1] → -0.2
  let s = memory.sentiment(mem)
  let assert True = s <. -0.19
  let assert True = s >. -0.21
}

pub fn sentiment_clamped_high_test() {
  let mem =
    memory.new(50)
    |> memory.adjust_sentiment(0.8)
    |> memory.adjust_sentiment(0.8)
  // 1.6 clamped to 1.0
  memory.sentiment(mem) |> should.equal(1.0)
}

pub fn sentiment_clamped_low_test() {
  let mem =
    memory.new(50)
    |> memory.adjust_sentiment(-0.8)
    |> memory.adjust_sentiment(-0.8)
  // -1.6 clamped to -1.0
  memory.sentiment(mem) |> should.equal(-1.0)
}
