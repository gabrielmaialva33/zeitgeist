import gleam/dict
import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/core/entity
import zeitgeist/graph/fact.{AtomicFact}
import zeitgeist/graph/store

pub fn main() {
  gleeunit.main()
}

pub fn upsert_and_get_entity_test() {
  let assert Ok(graph) = store.start("test_e_" <> unique())
  let e =
    entity.Entity(
      id: "usa",
      kind: entity.Government,
      name: "United States",
      aliases: ["US", "USA"],
      attributes: dict.new(),
    )
  store.upsert_entity(graph, e)
  let assert Ok(found) = store.get_entity(graph, "usa")
  found.name |> should.equal("United States")
  store.stop(graph)
}

pub fn upsert_and_get_fact_test() {
  let assert Ok(graph) = store.start("test_f_" <> unique())
  let f =
    AtomicFact(
      id: "f1",
      subject: "usa",
      predicate: entity.Allied,
      object: "uk",
      observed_at: 1_000_000,
      valid_from: 1_000_000,
      valid_until: None,
      confidence: 0.9,
      source_credibility: 0.95,
      frequency: 3,
    )
  store.upsert_fact(graph, f)
  let assert Ok(found) = store.get_fact(graph, "f1")
  found.confidence |> should.equal(0.9)
  store.stop(graph)
}

pub fn entity_count_test() {
  let assert Ok(graph) = store.start("test_c_" <> unique())
  store.entity_count(graph) |> should.equal(0)
  store.upsert_entity(
    graph,
    entity.Entity(
      id: "a",
      kind: entity.Person,
      name: "Alice",
      aliases: [],
      attributes: dict.new(),
    ),
  )
  store.entity_count(graph) |> should.equal(1)
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
