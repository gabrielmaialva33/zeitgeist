import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/core/bus
import zeitgeist/core/entity
import zeitgeist/core/event
import zeitgeist/core/event_store
import zeitgeist/graph/fact.{AtomicFact}
import zeitgeist/graph/store
import zeitgeist/risk/cii
import zeitgeist/risk/cii_server

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

pub fn p1_event_store_integration_test() {
  let assert Ok(b) = bus.start()
  let assert Ok(es) = event_store.start("p1_integ_" <> unique(), 1000)
  let assert Ok(cii_srv) = cii_server.start(b)

  // Push events directly into event store (bus bridge tested separately)
  let news_evt =
    event.Event(
      id: "p1_news_001",
      timestamp: 1_774_100_000_000,
      kind: event.NewsArticle(
        title: "P1 test event",
        summary: "integration test",
        category: event.General,
      ),
      source: event.RealWorld("test"),
      location: None,
      entities: [],
      confidence: 0.9,
      raw: None,
    )
  event_store.push(es, news_evt)

  let seismic_evt =
    event.Event(
      id: "p1_seismic_001",
      timestamp: 1_774_100_001_000,
      kind: event.SeismicReading(magnitude: 5.2, depth_km: 15.0),
      source: event.RealWorld("usgs"),
      location: None,
      entities: [],
      confidence: 0.95,
      raw: None,
    )
  event_store.push(es, seismic_evt)

  // Verify events in store
  let size = event_store.get_size(es)
  size |> should.equal(2)

  let recent = event_store.recent(es, 10)
  let found_news =
    list_any(recent, fn(e: event.Event) { e.id == "p1_news_001" })
  let assert True = found_news

  // Verify by stream
  let seismic_events =
    event_store.by_stream(es, event.SeismicStream, 10)
  list.length(seismic_events) |> should.equal(1)

  // Update CII, verify score > 0
  cii_server.update_country(cii_srv, "SY", 75.0)
  process.sleep(50)
  let risk = cii_server.get_country(cii_srv, "SY")
  let assert True = risk.cii_score >. 0.0

  event_store.stop(es)
  cii_server.stop(cii_srv)
}

fn list_any(lst: List(a), pred: fn(a) -> Bool) -> Bool {
  case lst {
    [] -> False
    [head, ..tail] ->
      case pred(head) {
        True -> True
        False -> list_any(tail, pred)
      }
  }
}

@external(erlang, "erlang", "unique_integer")
fn unique_int() -> Int

fn unique() -> String {
  int_to_string(unique_int())
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string(i: Int) -> String
