import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/core/event

pub fn main() {
  gleeunit.main()
}

pub fn new_event_test() {
  let e =
    event.new("evt_001", event.NewsArticle(
      title: "Test headline",
      summary: "Summary text",
      category: event.Politics,
    ))
  e.id |> should.equal("evt_001")
  e.confidence |> should.equal(0.5)
  e.location |> should.equal(None)
}

pub fn event_stream_from_kind_test() {
  event.stream_from_kind(event.NewsArticle(
    title: "",
    summary: "",
    category: event.Politics,
  ))
  |> should.equal(event.NewsStream)

  event.stream_from_kind(event.MarketTick(
    symbol: "BTC",
    price: 100_000.0,
    change_pct: 1.5,
  ))
  |> should.equal(event.MarketStream)
}
