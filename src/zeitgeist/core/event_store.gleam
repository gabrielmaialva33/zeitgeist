import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import zeitgeist/core/event.{type Event, type EventStream}

pub type StoreMsg {
  Push(event: Event)
  Recent(limit: Int, reply_to: Subject(List(Event)))
  ByStream(stream: EventStream, limit: Int, reply_to: Subject(List(Event)))
  CountSince(stream: EventStream, since_ms: Int, reply_to: Subject(Int))
  GetSize(reply_to: Subject(Int))
  Stop
}

type StoreState {
  StoreState(events: List(Event), max_size: Int)
}

pub fn start(
  _prefix: String,
  max_size: Int,
) -> Result(Subject(StoreMsg), actor.StartError) {
  let r =
    actor.new(StoreState(events: [], max_size: max_size))
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn push(store: Subject(StoreMsg), event: Event) -> Nil {
  process.send(store, Push(event))
}

pub fn recent(store: Subject(StoreMsg), limit: Int) -> List(Event) {
  process.call(store, waiting: 5000, sending: fn(reply_to) {
    Recent(limit, reply_to)
  })
}

pub fn by_stream(
  store: Subject(StoreMsg),
  stream: EventStream,
  limit: Int,
) -> List(Event) {
  process.call(store, waiting: 5000, sending: fn(reply_to) {
    ByStream(stream, limit, reply_to)
  })
}

pub fn count_since(
  store: Subject(StoreMsg),
  stream: EventStream,
  since_ms: Int,
) -> Int {
  process.call(store, waiting: 5000, sending: fn(reply_to) {
    CountSince(stream, since_ms, reply_to)
  })
}

pub fn get_size(store: Subject(StoreMsg)) -> Int {
  process.call(store, waiting: 5000, sending: fn(reply_to) {
    GetSize(reply_to)
  })
}

pub fn stop(store: Subject(StoreMsg)) -> Nil {
  process.send(store, Stop)
}

fn handle_message(
  state: StoreState,
  msg: StoreMsg,
) -> actor.Next(StoreState, StoreMsg) {
  case msg {
    Push(evt) -> {
      let new_events = [evt, ..state.events]
      let capped = case list.length(new_events) > state.max_size {
        True -> list.take(new_events, state.max_size)
        False -> new_events
      }
      actor.continue(StoreState(..state, events: capped))
    }
    Recent(limit, reply_to) -> {
      let result = list.take(state.events, limit)
      process.send(reply_to, result)
      actor.continue(state)
    }
    ByStream(stream, limit, reply_to) -> {
      let filtered =
        list.filter(state.events, fn(e) {
          event.stream_from_kind(e.kind) == stream
        })
      let result = list.take(filtered, limit)
      process.send(reply_to, result)
      actor.continue(state)
    }
    CountSince(stream, since_ms, reply_to) -> {
      let count =
        list.count(state.events, fn(e) {
          event.stream_from_kind(e.kind) == stream && e.timestamp >= since_ms
        })
      process.send(reply_to, count)
      actor.continue(state)
    }
    GetSize(reply_to) -> {
      process.send(reply_to, list.length(state.events))
      actor.continue(state)
    }
    Stop -> actor.stop()
  }
}
