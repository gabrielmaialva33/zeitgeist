import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/option.{None}
import gleam/otp/actor
import zeitgeist/core/bus
import zeitgeist/core/event
import zeitgeist/signal/source.{type SourceConfig, ConflictSource}

pub type ConflictMsg {
  PollConflict
  GetConflictHealth(reply_to: Subject(source.SourceHealth))
  StopConflict
}

type ConflictState {
  ConflictState(
    config: SourceConfig,
    bus: Subject(bus.BusMsg),
    self: Subject(ConflictMsg),
    events_total: Int,
    last_event_at: Int,
    error_count: Int,
  )
}

pub fn start(
  config: SourceConfig,
  bus: Subject(bus.BusMsg),
) -> Result(Subject(ConflictMsg), actor.StartError) {
  let r =
    actor.new_with_initialiser(5000, fn(self) {
      let state =
        ConflictState(
          config: config,
          bus: bus,
          self: self,
          events_total: 0,
          last_event_at: 0,
          error_count: 0,
        )
      let assert ConflictSource(_, _, poll_interval_ms) = config
      process.send_after(self, poll_interval_ms, PollConflict)
      state
      |> actor.initialised
      |> actor.selecting(process.new_selector() |> process.select(self))
      |> actor.returning(self)
      |> Ok
    })
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

fn handle_message(
  state: ConflictState,
  msg: ConflictMsg,
) -> actor.Next(ConflictState, ConflictMsg) {
  case msg {
    PollConflict -> {
      let assert ConflictSource(id, _url, poll_interval_ms) = state.config
      let ts = now_ms()
      let evt =
        event.Event(
          id: "conflict_"
            <> id
            <> "_"
            <> int.to_string(state.events_total),
          timestamp: ts,
          kind: event.NewsArticle(
            title: "Conflict event",
            summary: "ACLED stub",
            category: event.Conflict,
          ),
          source: event.RealWorld(id),
          location: None,
          entities: [],
          confidence: 0.7,
          raw: None,
        )
      process.send(state.bus, bus.Publish(evt))
      process.send_after(state.self, poll_interval_ms, PollConflict)
      actor.continue(
        ConflictState(
          ..state,
          events_total: state.events_total + 1,
          last_event_at: ts,
        ),
      )
    }
    GetConflictHealth(reply_to) -> {
      let assert ConflictSource(id, _, _) = state.config
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
    StopConflict -> actor.stop()
  }
}

@external(erlang, "zeitgeist_ets_ffi", "now_ms")
fn now_ms() -> Int
