import gleam/list
import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/core/event
import zeitgeist/core/event_store

pub fn main() {
  gleeunit.main()
}

fn make_news(id: String, title: String, ts: Int) -> event.Event {
  event.Event(
    id: id,
    timestamp: ts,
    kind: event.NewsArticle(
      title: title,
      summary: "summary",
      category: event.General,
    ),
    source: event.RealWorld("test"),
    location: None,
    entities: [],
    confidence: 0.8,
    raw: None,
  )
}

fn make_market(id: String, ts: Int) -> event.Event {
  event.Event(
    id: id,
    timestamp: ts,
    kind: event.MarketTick(symbol: "BTC", price: 50_000.0, change_pct: 1.0),
    source: event.RealWorld("test"),
    location: None,
    entities: [],
    confidence: 0.9,
    raw: None,
  )
}

fn ids(events: List(event.Event)) -> List(String) {
  list.map(events, fn(e) { e.id })
}

pub fn store_and_retrieve_test() {
  let assert Ok(store) = event_store.start("test_store_1", 100)
  let e1 = make_news("e1", "Headline 1", 1000)
  let e2 = make_news("e2", "Headline 2", 2000)

  event_store.push(store, e1)
  event_store.push(store, e2)

  let recent = event_store.recent(store, 10)
  // most recent first
  recent |> should.equal([e2, e1])

  event_store.stop(store)
}

pub fn max_size_eviction_test() {
  let assert Ok(store) = event_store.start("test_store_2", 3)

  event_store.push(store, make_news("e1", "H1", 1000))
  event_store.push(store, make_news("e2", "H2", 2000))
  event_store.push(store, make_news("e3", "H3", 3000))
  event_store.push(store, make_news("e4", "H4", 4000))

  // capped at 3, oldest evicted
  event_store.get_size(store) |> should.equal(3)

  let recent = event_store.recent(store, 10)
  ids(recent) |> should.equal(["e4", "e3", "e2"])

  event_store.stop(store)
}

pub fn filter_by_stream_test() {
  let assert Ok(store) = event_store.start("test_store_3", 100)

  event_store.push(store, make_news("n1", "News 1", 1000))
  event_store.push(store, make_market("m1", 2000))
  event_store.push(store, make_news("n2", "News 2", 3000))

  let news = event_store.by_stream(store, event.NewsStream, 10)
  ids(news) |> should.equal(["n2", "n1"])

  let market = event_store.by_stream(store, event.MarketStream, 10)
  ids(market) |> should.equal(["m1"])

  event_store.stop(store)
}

pub fn count_since_test() {
  let assert Ok(store) = event_store.start("test_store_4", 100)

  event_store.push(store, make_news("n1", "Old news", 1000))
  event_store.push(store, make_news("n2", "Recent news 1", 5000))
  event_store.push(store, make_news("n3", "Recent news 2", 6000))
  event_store.push(store, make_market("m1", 7000))

  // count news events since ts=4000
  event_store.count_since(store, event.NewsStream, 4000) |> should.equal(2)

  // count all news
  event_store.count_since(store, event.NewsStream, 0) |> should.equal(3)

  event_store.stop(store)
}

pub fn recent_limit_test() {
  let assert Ok(store) = event_store.start("test_store_5", 100)

  event_store.push(store, make_news("e1", "H1", 1000))
  event_store.push(store, make_news("e2", "H2", 2000))
  event_store.push(store, make_news("e3", "H3", 3000))

  let recent = event_store.recent(store, 2)
  list.length(recent) |> should.equal(2)
  ids(recent) |> should.equal(["e3", "e2"])

  event_store.stop(store)
}
