// WebSocket connection manager — tracks clients, broadcasts events
import gleam/erlang/process.{type Subject}
import gleam/json
import gleam/list
import gleam/otp/actor
import zeitgeist/core/event.{type Event}
import zeitgeist/web/json_encode

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

pub type WsMsg {
  AddClient(client: Subject(String))
  RemoveClient(client: Subject(String))
  BroadcastEvent(event: Event)
  WsClientCount(reply_to: Subject(Int))
  WsStop
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

type WsState {
  WsState(clients: List(Subject(String)))
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn start() -> Result(Subject(WsMsg), actor.StartError) {
  let init = WsState(clients: [])
  let r =
    actor.new(init)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn add_client(ws: Subject(WsMsg), client: Subject(String)) -> Nil {
  process.send(ws, AddClient(client: client))
}

pub fn remove_client(ws: Subject(WsMsg), client: Subject(String)) -> Nil {
  process.send(ws, RemoveClient(client: client))
}

pub fn broadcast(ws: Subject(WsMsg), event: Event) -> Nil {
  process.send(ws, BroadcastEvent(event: event))
}

pub fn client_count(ws: Subject(WsMsg)) -> Int {
  process.call(ws, waiting: 5000, sending: fn(reply_to) {
    WsClientCount(reply_to: reply_to)
  })
}

pub fn stop(ws: Subject(WsMsg)) -> Nil {
  process.send(ws, WsStop)
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

fn handle_message(state: WsState, msg: WsMsg) -> actor.Next(WsState, WsMsg) {
  case msg {
    AddClient(client) -> {
      let new_clients = [client, ..state.clients]
      actor.continue(WsState(clients: new_clients))
    }

    RemoveClient(client) -> {
      let new_clients =
        list.filter(state.clients, fn(c) { c != client })
      actor.continue(WsState(clients: new_clients))
    }

    BroadcastEvent(event) -> {
      let json_str = json_encode.event_json(event) |> json.to_string
      list.each(state.clients, fn(client) {
        process.send(client, json_str)
      })
      actor.continue(state)
    }

    WsClientCount(reply_to) -> {
      process.send(reply_to, list.length(state.clients))
      actor.continue(state)
    }

    WsStop -> actor.stop()
  }
}
