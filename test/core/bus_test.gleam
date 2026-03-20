import gleam/erlang/process
import gleeunit
import gleeunit/should
import zeitgeist/core/bus
import zeitgeist/core/event

pub fn main() {
  gleeunit.main()
}

pub fn subscribe_and_receive_test() {
  let assert Ok(bus_subject) = bus.start()
  let receiver = process.new_subject()
  process.send(bus_subject, bus.Subscribe(event.NewsStream, receiver))

  let evt =
    event.new(
      "test_1",
      event.NewsArticle(title: "Test", summary: "Test", category: event.General),
    )
  process.send(bus_subject, bus.Publish(evt))

  let assert Ok(received) = process.receive(receiver, 1000)
  received.id |> should.equal("test_1")
}

pub fn wrong_stream_not_received_test() {
  let assert Ok(bus_subject) = bus.start()
  let receiver = process.new_subject()
  process.send(bus_subject, bus.Subscribe(event.MarketStream, receiver))

  let evt =
    event.new(
      "test_2",
      event.NewsArticle(title: "Test", summary: "Test", category: event.General),
    )
  process.send(bus_subject, bus.Publish(evt))

  let result = process.receive(receiver, 100)
  should.be_error(result)
}

pub fn stats_test() {
  let assert Ok(bus_subject) = bus.start()
  let stats = bus.get_stats(bus_subject)
  stats.total_published |> should.equal(0)
  stats.subscriber_count |> should.equal(0)
}
