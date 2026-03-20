import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import gleam/result
import zeitgeist/core/event.{type Event, type EventStream}

pub type BusMsg {
  Subscribe(stream: EventStream, subscriber: Subject(Event))
  Unsubscribe(stream: EventStream, subscriber: Subject(Event))
  Publish(event: Event)
  GetStats(reply_to: Subject(BusStats))
}

pub type BusStats {
  BusStats(total_published: Int, subscriber_count: Int)
}

type BusState {
  BusState(
    subscribers: Dict(EventStream, List(Subject(Event))),
    total_published: Int,
  )
}

pub fn start() -> Result(Subject(BusMsg), actor.StartError) {
  let r =
    actor.new(BusState(subscribers: dict.new(), total_published: 0))
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn get_stats(bus: Subject(BusMsg)) -> BusStats {
  process.call(bus, waiting: 5000, sending: fn(reply_to) { GetStats(reply_to) })
}

fn handle_message(
  state: BusState,
  msg: BusMsg,
) -> actor.Next(BusState, BusMsg) {
  case msg {
    Subscribe(stream, subscriber) -> {
      let current = dict.get(state.subscribers, stream) |> result.unwrap([])
      let updated =
        dict.insert(state.subscribers, stream, [subscriber, ..current])
      actor.continue(BusState(..state, subscribers: updated))
    }
    Unsubscribe(stream, subscriber) -> {
      let current = dict.get(state.subscribers, stream) |> result.unwrap([])
      let filtered = list.filter(current, fn(s) { s != subscriber })
      let updated = dict.insert(state.subscribers, stream, filtered)
      actor.continue(BusState(..state, subscribers: updated))
    }
    Publish(evt) -> {
      let stream = event.stream_from_kind(evt.kind)
      let subs = dict.get(state.subscribers, stream) |> result.unwrap([])
      list.each(subs, fn(sub) { process.send(sub, evt) })
      actor.continue(
        BusState(..state, total_published: state.total_published + 1),
      )
    }
    GetStats(reply_to) -> {
      let count =
        dict.fold(state.subscribers, 0, fn(acc, _k, v) {
          acc + list.length(v)
        })
      process.send(
        reply_to,
        BusStats(
          total_published: state.total_published,
          subscriber_count: count,
        ),
      )
      actor.continue(state)
    }
  }
}
