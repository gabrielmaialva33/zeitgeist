import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/option.{None}
import gleam/otp/actor
import zeitgeist/core/bus
import zeitgeist/core/event
import zeitgeist/signal/source.{type SourceConfig, RssFeed}

pub type RssMsg {
  Poll
  GetHealth(reply_to: Subject(source.SourceHealth))
  Stop
}

type RssState {
  RssState(
    config: SourceConfig,
    bus: Subject(bus.BusMsg),
    events_total: Int,
    last_event_at: Int,
    error_count: Int,
  )
}

pub fn start(
  config: SourceConfig,
  bus: Subject(bus.BusMsg),
) -> Result(Subject(RssMsg), actor.StartError) {
  let state =
    RssState(
      config: config,
      bus: bus,
      events_total: 0,
      last_event_at: 0,
      error_count: 0,
    )
  let r = actor.new(state) |> actor.on_message(handle_message) |> actor.start
  case r {
    Ok(started) -> {
      let assert RssFeed(_, _, poll_interval_ms) = config
      process.send_after(started.data, poll_interval_ms, Poll)
      Ok(started.data)
    }
    Error(e) -> Error(e)
  }
}

fn handle_message(state: RssState, msg: RssMsg) -> actor.Next(RssState, RssMsg) {
  case msg {
    Poll -> {
      let assert RssFeed(id, url, _poll_interval_ms) = state.config
      let ts = now_ms()
      let evt =
        event.Event(
          id: "rss_" <> id <> "_" <> int.to_string(state.events_total),
          timestamp: ts,
          kind: event.NewsArticle(
            title: "Poll #"
              <> int.to_string(state.events_total)
              <> " from "
              <> id,
            summary: "Stub event from RSS source " <> url,
            category: event.General,
          ),
          source: event.RealWorld(id),
          location: None,
          entities: [],
          confidence: 0.5,
          raw: None,
        )
      process.send(state.bus, bus.Publish(evt))
      // NOTE: For P0, we don't reschedule polls. The stub fires once.
      // TODO P1: Add self_subject scheduling for continuous polling
      actor.continue(
        RssState(
          ..state,
          events_total: state.events_total + 1,
          last_event_at: ts,
        ),
      )
    }
    GetHealth(reply_to) -> {
      let assert RssFeed(id, _, _) = state.config
      process.send(
        reply_to,
        source.SourceHealth(
          source_id: id,
          status: source.Active,
          events_total: state.events_total,
          last_event_at: state.last_event_at,
          error_count: state.error_count,
        ),
      )
      actor.continue(state)
    }
    Stop -> actor.stop()
  }
}

@external(erlang, "zeitgeist_ets_ffi", "now_ms")
fn now_ms() -> Int
