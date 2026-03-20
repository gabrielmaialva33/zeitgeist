import gleam/erlang/process
import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/core/entity
import zeitgeist/graph/fact.{AtomicFact}
import zeitgeist/graph/snapshot
import zeitgeist/graph/store

pub fn main() {
  gleeunit.main()
}

pub fn old_facts_pruned_test() {
  let assert Ok(graph) = store.start("snap_old_" <> unique())
  // observed_at = 0 is ancient (way older than 1 hour)
  store.upsert_fact(
    graph,
    AtomicFact(
      id: "old1",
      subject: "entity_a",
      predicate: entity.Allied,
      object: "entity_b",
      observed_at: 0,
      valid_from: 0,
      valid_until: None,
      confidence: 0.9,
      source_credibility: 0.9,
      frequency: 1,
    ),
  )
  store.fact_count(graph) |> should.equal(1)
  snapshot.run_decay(graph, 1)
  // Give actor a moment to process the async message
  process.sleep(50)
  store.fact_count(graph) |> should.equal(0)
  store.stop(graph)
}

pub fn fresh_facts_survive_test() {
  let assert Ok(graph) = store.start("snap_fresh_" <> unique())
  // Use current time so fact is not old at all
  let now = now_ms()
  store.upsert_fact(
    graph,
    AtomicFact(
      id: "fresh1",
      subject: "entity_c",
      predicate: entity.TradePartner,
      object: "entity_d",
      observed_at: now,
      valid_from: now,
      valid_until: None,
      confidence: 0.8,
      source_credibility: 0.85,
      frequency: 2,
    ),
  )
  store.fact_count(graph) |> should.equal(1)
  snapshot.run_decay(graph, 24)
  process.sleep(50)
  store.fact_count(graph) |> should.equal(1)
  store.stop(graph)
}

pub fn mixed_facts_test() {
  let assert Ok(graph) = store.start("snap_mix_" <> unique())
  let now = now_ms()
  // Old fact: observed_at = 0
  store.upsert_fact(
    graph,
    AtomicFact(
      id: "old_m",
      subject: "x",
      predicate: entity.Hostile,
      object: "y",
      observed_at: 0,
      valid_from: 0,
      valid_until: None,
      confidence: 0.7,
      source_credibility: 0.7,
      frequency: 1,
    ),
  )
  // Fresh fact
  store.upsert_fact(
    graph,
    AtomicFact(
      id: "fresh_m",
      subject: "x",
      predicate: entity.Allied,
      object: "z",
      observed_at: now,
      valid_from: now,
      valid_until: None,
      confidence: 0.9,
      source_credibility: 0.9,
      frequency: 1,
    ),
  )
  store.fact_count(graph) |> should.equal(2)
  snapshot.run_decay(graph, 1)
  process.sleep(50)
  store.fact_count(graph) |> should.equal(1)
  store.stop(graph)
}

fn unique() -> String {
  let i = erlang_unique_int()
  gleam_int_to_string(i)
}

@external(erlang, "erlang", "unique_integer")
fn erlang_unique_int() -> Int

@external(erlang, "erlang", "integer_to_binary")
fn gleam_int_to_string(i: Int) -> String

@external(erlang, "zeitgeist_ets_ffi", "now_ms")
fn now_ms() -> Int
