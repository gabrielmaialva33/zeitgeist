import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/string
import zeitgeist/core/bus
import zeitgeist/core/event
import zeitgeist/signal/source.{type SourceConfig, RssFeed}

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub type RssItem {
  RssItem(title: String, link: String, description: String)
}

pub type RssMsg {
  Poll
  GetHealth(reply_to: Subject(source.SourceHealth))
  Stop
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

type RssState {
  RssState(
    config: SourceConfig,
    bus: Subject(bus.BusMsg),
    self_subject: Subject(RssMsg),
    events_total: Int,
    last_event_at: Int,
    error_count: Int,
    seen_titles: List(String),
  )
}

// ---------------------------------------------------------------------------
// FFI
// ---------------------------------------------------------------------------

@external(erlang, "zeitgeist_xml_ffi", "http_get")
fn http_get_ffi(url: String, timeout_ms: Int) -> Result(String, String)

@external(erlang, "zeitgeist_xml_ffi", "parse_rss")
fn parse_rss_ffi(xml: String) -> List(#(String, String, String))

@external(erlang, "zeitgeist_ets_ffi", "now_ms")
fn now_ms() -> Int

// ---------------------------------------------------------------------------
// Public API — parse_xml exposed for testing
// ---------------------------------------------------------------------------

pub fn parse_xml(xml_string: String) -> Result(List(RssItem), String) {
  let tuples = parse_rss_ffi(xml_string)
  let items =
    list.filter_map(tuples, fn(t) {
      let #(title, link, desc) = t
      case string.is_empty(title) && string.is_empty(link) {
        True -> Error(Nil)
        False -> Ok(RssItem(title: title, link: link, description: desc))
      }
    })
  Ok(items)
}

// ---------------------------------------------------------------------------
// Start — uses new_with_initialiser to capture the subject for self-scheduling
// ---------------------------------------------------------------------------

pub fn start(
  config: SourceConfig,
  bus: Subject(bus.BusMsg),
) -> Result(Subject(RssMsg), actor.StartError) {
  let assert RssFeed(_, _, poll_interval_ms) = config
  let init_config = config
  let init_bus = bus

  let r =
    actor.new_with_initialiser(5000, fn(subject) {
      let state =
        RssState(
          config: init_config,
          bus: init_bus,
          self_subject: subject,
          events_total: 0,
          last_event_at: 0,
          error_count: 0,
          seen_titles: [],
        )
      // Schedule first poll
      process.send_after(subject, poll_interval_ms, Poll)
      actor.initialised(state) |> actor.returning(subject) |> Ok
    })
    |> actor.on_message(handle_message)
    |> actor.start

  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

fn handle_message(state: RssState, msg: RssMsg) -> actor.Next(RssState, RssMsg) {
  case msg {
    Poll -> handle_poll(state)
    GetHealth(reply_to) -> handle_health(state, reply_to)
    Stop -> actor.stop()
  }
}

fn handle_poll(state: RssState) -> actor.Next(RssState, RssMsg) {
  let assert RssFeed(id, url, poll_interval_ms) = state.config
  let #(new_items, err_count, new_seen) = do_poll(url, state.seen_titles)
  let ts = now_ms()

  list.each(new_items, fn(item) {
    let evt =
      event.Event(
        id: "rss_"
          <> id
          <> "_"
          <> int.to_string(state.events_total)
          <> "_"
          <> int.to_string(ts),
        timestamp: ts,
        kind: event.NewsArticle(
          title: item.title,
          summary: item.description,
          category: event.General,
        ),
        source: event.RealWorld(id),
        location: None,
        entities: [],
        confidence: 0.8,
        raw: Some(item.link),
      )
    process.send(state.bus, bus.Publish(evt))
  })

  // Reschedule next poll
  process.send_after(state.self_subject, poll_interval_ms, Poll)

  let new_error_count = state.error_count + err_count
  let new_total = state.events_total + list.length(new_items)
  let new_last = case new_items != [] {
    True -> ts
    False -> state.last_event_at
  }
  actor.continue(
    RssState(
      ..state,
      events_total: new_total,
      last_event_at: new_last,
      error_count: new_error_count,
      seen_titles: new_seen,
    ),
  )
}

fn handle_health(
  state: RssState,
  reply_to: Subject(source.SourceHealth),
) -> actor.Next(RssState, RssMsg) {
  let assert RssFeed(id, _, _) = state.config
  let status = case state.error_count > 5 {
    True ->
      source.SourceDegraded(
        "high error count: " <> int.to_string(state.error_count),
      )
    False -> source.Active
  }
  process.send(
    reply_to,
    source.SourceHealth(
      source_id: id,
      status: status,
      events_total: state.events_total,
      last_event_at: state.last_event_at,
      error_count: state.error_count,
    ),
  )
  actor.continue(state)
}

// ---------------------------------------------------------------------------
// Poll logic
// ---------------------------------------------------------------------------

fn do_poll(
  url: String,
  seen_titles: List(String),
) -> #(List(RssItem), Int, List(String)) {
  case http_get_ffi(url, 10_000) {
    Error(_) -> #([], 1, seen_titles)
    Ok(xml) -> {
      case parse_xml(xml) {
        Error(_) -> #([], 1, seen_titles)
        Ok(items) -> {
          let new_items =
            list.filter(items, fn(item) {
              !list.contains(seen_titles, item.title)
            })
          let all_titles = list.map(items, fn(i) { i.title })
          let updated_seen =
            list.take(list.append(all_titles, seen_titles), 500)
          #(new_items, 0, updated_seen)
        }
      }
    }
  }
}
