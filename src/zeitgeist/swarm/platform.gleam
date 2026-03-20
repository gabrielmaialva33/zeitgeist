import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

pub type DiplomaticMsg {
  DiplomaticMsg(
    from: String,
    to: String,
    content: String,
    public: Bool,
    tick: Int,
  )
}

pub type PlatformMsg {
  SendMessage(msg: DiplomaticMsg)
  GetMessages(
    recipient: String,
    limit: Int,
    reply_to: Subject(List(DiplomaticMsg)),
  )
  GetPublicMessages(limit: Int, reply_to: Subject(List(DiplomaticMsg)))
  MessageCount(reply_to: Subject(Int))
  PlatformStop
}

type PlatformState {
  PlatformState(world_id: String, messages: List(DiplomaticMsg))
}

pub fn start(
  world_id: String,
) -> Result(Subject(PlatformMsg), actor.StartError) {
  let init_state = PlatformState(world_id: world_id, messages: [])
  let r =
    actor.new(init_state)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn send_message(plat: Subject(PlatformMsg), msg: DiplomaticMsg) -> Nil {
  process.send(plat, SendMessage(msg))
}

pub fn get_messages(
  plat: Subject(PlatformMsg),
  recipient: String,
  limit: Int,
) -> List(DiplomaticMsg) {
  process.call(plat, waiting: 5000, sending: fn(reply_to) {
    GetMessages(recipient, limit, reply_to)
  })
}

pub fn get_public_messages(
  plat: Subject(PlatformMsg),
  limit: Int,
) -> List(DiplomaticMsg) {
  process.call(plat, waiting: 5000, sending: fn(reply_to) {
    GetPublicMessages(limit, reply_to)
  })
}

pub fn message_count(plat: Subject(PlatformMsg)) -> Int {
  process.call(plat, waiting: 5000, sending: fn(reply_to) {
    MessageCount(reply_to)
  })
}

pub fn stop(plat: Subject(PlatformMsg)) -> Nil {
  process.send(plat, PlatformStop)
}

fn handle_message(
  state: PlatformState,
  msg: PlatformMsg,
) -> actor.Next(PlatformState, PlatformMsg) {
  case msg {
    SendMessage(diplomatic_msg) -> {
      let new_messages = [diplomatic_msg, ..state.messages]
      actor.continue(PlatformState(..state, messages: new_messages))
    }

    GetMessages(recipient, limit, reply_to) -> {
      let filtered =
        list.filter(state.messages, fn(m) {
          m.to == recipient || m.to == "all"
        })
      let result = list.take(filtered, limit)
      process.send(reply_to, result)
      actor.continue(state)
    }

    GetPublicMessages(limit, reply_to) -> {
      let filtered = list.filter(state.messages, fn(m) { m.public == True })
      let result = list.take(filtered, limit)
      process.send(reply_to, result)
      actor.continue(state)
    }

    MessageCount(reply_to) -> {
      process.send(reply_to, list.length(state.messages))
      actor.continue(state)
    }

    PlatformStop -> actor.stop()
  }
}
