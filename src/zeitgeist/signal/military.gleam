import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/option.{None}
import gleam/otp/actor
import zeitgeist/core/bus
import zeitgeist/core/event
import zeitgeist/signal/source.{type SourceConfig, MilitarySource}

pub type MilitaryMsg {
  MilitaryPoll
  GetMilitaryHealth(reply_to: Subject(source.SourceHealth))
  MilitarySourceStop
}

type MilitaryState {
  MilitaryState(
    config: SourceConfig,
    bus: Subject(bus.BusMsg),
    self: Subject(MilitaryMsg),
    events_total: Int,
    last_event_at: Int,
    error_count: Int,
  )
}

pub fn start(
  config: SourceConfig,
  bus: Subject(bus.BusMsg),
) -> Result(Subject(MilitaryMsg), actor.StartError) {
  let r =
    actor.new_with_initialiser(5000, fn(self) {
      let state =
        MilitaryState(
          config: config,
          bus: bus,
          self: self,
          events_total: 0,
          last_event_at: 0,
          error_count: 0,
        )
      let assert MilitarySource(_, _, poll_interval_ms) = config
      process.send_after(self, poll_interval_ms, MilitaryPoll)
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
  state: MilitaryState,
  msg: MilitaryMsg,
) -> actor.Next(MilitaryState, MilitaryMsg) {
  case msg {
    MilitaryPoll -> {
      let assert MilitarySource(id, _url, poll_interval_ms) = state.config
      let ts = now_ms()
      let evt =
        event.Event(
          id: "military_" <> id <> "_" <> int.to_string(state.events_total),
          timestamp: ts,
          kind: event.MilitaryTrack(
            track_type: event.Aircraft,
            callsign: "STUB_" <> id,
            heading: 0.0,
          ),
          source: event.RealWorld(id),
          location: None,
          entities: [],
          confidence: 0.75,
          raw: None,
        )
      process.send(state.bus, bus.Publish(evt))
      process.send_after(state.self, poll_interval_ms, MilitaryPoll)
      actor.continue(
        MilitaryState(
          ..state,
          events_total: state.events_total + 1,
          last_event_at: ts,
        ),
      )
    }
    GetMilitaryHealth(reply_to) -> {
      let assert MilitarySource(id, _, _) = state.config
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
    MilitarySourceStop -> actor.stop()
  }
}

@external(erlang, "zeitgeist_ets_ffi", "now_ms")
fn now_ms() -> Int
