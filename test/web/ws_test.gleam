import gleam/erlang/process
import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/core/event
import zeitgeist/web/ws

pub fn main() {
  gleeunit.main()
}

pub fn add_client_increases_count_test() {
  let assert Ok(mgr) = ws.start()

  ws.client_count(mgr) |> should.equal(0)

  let client1 = process.new_subject()
  ws.add_client(mgr, client1)
  process.sleep(10)

  ws.client_count(mgr) |> should.equal(1)

  let client2 = process.new_subject()
  ws.add_client(mgr, client2)
  process.sleep(10)

  ws.client_count(mgr) |> should.equal(2)

  ws.stop(mgr)
}

pub fn remove_client_decreases_count_test() {
  let assert Ok(mgr) = ws.start()

  let client1 = process.new_subject()
  let client2 = process.new_subject()

  ws.add_client(mgr, client1)
  ws.add_client(mgr, client2)
  process.sleep(10)
  ws.client_count(mgr) |> should.equal(2)

  ws.remove_client(mgr, client1)
  process.sleep(10)
  ws.client_count(mgr) |> should.equal(1)

  ws.stop(mgr)
}

pub fn broadcast_delivers_to_clients_test() {
  let assert Ok(mgr) = ws.start()

  let client = process.new_subject()
  ws.add_client(mgr, client)
  process.sleep(10)

  let evt =
    event.Event(
      id: "ws_test_001",
      timestamp: 1_000_000,
      kind: event.NewsArticle(
        title: "Test broadcast",
        summary: "Testing WS broadcast",
        category: event.General,
      ),
      source: event.RealWorld("test"),
      location: None,
      entities: [],
      confidence: 0.9,
      raw: None,
    )

  ws.broadcast(mgr, evt)

  let assert Ok(msg) = process.receive(client, 1000)
  // JSON string should contain the event id
  let contains_id = contains_string(msg, "ws_test_001")
  contains_id |> should.equal(True)

  ws.stop(mgr)
}

pub fn remove_client_stops_receiving_test() {
  let assert Ok(mgr) = ws.start()

  let client = process.new_subject()
  ws.add_client(mgr, client)
  process.sleep(10)
  ws.remove_client(mgr, client)
  process.sleep(10)

  let evt =
    event.Event(
      id: "ws_test_002",
      timestamp: 2_000_000,
      kind: event.SeismicReading(magnitude: 4.5, depth_km: 10.0),
      source: event.RealWorld("usgs"),
      location: None,
      entities: [],
      confidence: 0.95,
      raw: None,
    )

  ws.broadcast(mgr, evt)

  // Should not receive anything since client was removed
  let result = process.receive(client, 200)
  result |> should.be_error

  ws.stop(mgr)
}

pub fn empty_broadcast_no_crash_test() {
  let assert Ok(mgr) = ws.start()

  let evt =
    event.Event(
      id: "ws_test_003",
      timestamp: 3_000_000,
      kind: event.SeismicReading(magnitude: 6.0, depth_km: 20.0),
      source: event.RealWorld("usgs"),
      location: None,
      entities: [],
      confidence: 0.9,
      raw: None,
    )

  // Should not crash with 0 clients
  ws.broadcast(mgr, evt)
  process.sleep(10)
  ws.client_count(mgr) |> should.equal(0)

  ws.stop(mgr)
}

// Simple string contains helper
fn contains_string(haystack: String, needle: String) -> Bool {
  string_contains_ffi(haystack, needle)
}

@external(erlang, "string", "find")
fn string_find(haystack: String, needle: String) -> String

fn string_contains_ffi(haystack: String, needle: String) -> Bool {
  string_find(haystack, needle) != ""
}
