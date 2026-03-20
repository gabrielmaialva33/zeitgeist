import gleam/dict
import gleam/erlang/process
import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/core/bus
import zeitgeist/core/entity
import zeitgeist/core/event
import zeitgeist/graph/fact.{AtomicFact}
import zeitgeist/graph/store
import zeitgeist/risk/cii

pub fn main() {
  gleeunit.main()
}

pub fn integration_event_flow_test() {
  let assert Ok(bus_subject) = bus.start()
  let assert Ok(graph_subject) = store.start("integ_" <> unique())

  // Subscribe to news
  let receiver = process.new_subject()
  process.send(bus_subject, bus.Subscribe(event.NewsStream, receiver))

  // Publish a news event
  let evt =
    event.Event(
      id: "test_001",
      timestamp: 1_774_017_000_000,
      kind: event.NewsArticle(
        title: "Conflict escalates in region X",
        summary: "Multiple incidents reported",
        category: event.Conflict,
      ),
      source: event.RealWorld("test"),
      location: None,
      entities: [],
      confidence: 0.9,
      raw: None,
    )
  process.send(bus_subject, bus.Publish(evt))

  // Verify subscriber received it
  let assert Ok(received) = process.receive(receiver, 1000)
  received.id |> should.equal("test_001")

  // Store entity + fact
  store.upsert_entity(
    graph_subject,
    entity.Entity(
      id: "region_x",
      kind: entity.Location,
      name: "Region X",
      aliases: [],
      attributes: dict.new(),
    ),
  )

  let fact =
    AtomicFact(
      id: "fact_001",
      subject: "region_x",
      predicate: entity.Hostile,
      object: "faction_a",
      observed_at: 1_774_017_000_000,
      valid_from: 1_774_017_000_000,
      valid_until: None,
      confidence: 0.9,
      source_credibility: 0.95,
      frequency: 1,
    )
  store.upsert_fact(graph_subject, fact)

  // Verify stored
  store.entity_count(graph_subject) |> should.equal(1)
  store.fact_count(graph_subject) |> should.equal(1)

  // CII scoring
  let risk = cii.new("XX") |> cii.update_score(80.0)
  let assert True = risk.cii_score >. 0.0

  store.stop(graph_subject)
}

@external(erlang, "erlang", "unique_integer")
fn unique_int() -> Int

fn unique() -> String {
  int_to_string(unique_int())
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string(i: Int) -> String
