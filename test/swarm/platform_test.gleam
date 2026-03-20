import gleeunit
import gleeunit/should
import zeitgeist/swarm/platform.{DiplomaticMsg}

pub fn main() {
  gleeunit.main()
}

pub fn send_and_receive_message_test() {
  let assert Ok(plat) = platform.start("world1")
  let msg =
    DiplomaticMsg(
      from: "usa",
      to: "china",
      content: "Let's talk trade.",
      public: False,
      tick: 1,
    )

  platform.send_message(plat, msg)

  let messages = platform.get_messages(plat, "china", 10)
  should.equal(1, list_length(messages))

  platform.stop(plat)
}

pub fn public_messages_visible_to_all_test() {
  let assert Ok(plat) = platform.start("world2")
  let msg =
    DiplomaticMsg(
      from: "usa",
      to: "all",
      content: "Global announcement.",
      public: True,
      tick: 1,
    )

  platform.send_message(plat, msg)

  let public = platform.get_public_messages(plat, 10)
  should.equal(1, list_length(public))

  platform.stop(plat)
}

pub fn message_count_test() {
  let assert Ok(plat) = platform.start("world3")
  let msg1 =
    DiplomaticMsg(from: "usa", to: "uk", content: "Hello.", public: False, tick: 1)
  let msg2 =
    DiplomaticMsg(
      from: "uk",
      to: "usa",
      content: "Hi back.",
      public: False,
      tick: 2,
    )

  platform.send_message(plat, msg1)
  platform.send_message(plat, msg2)

  let count = platform.message_count(plat)
  should.equal(2, count)

  platform.stop(plat)
}

fn list_length(lst: List(a)) -> Int {
  case lst {
    [] -> 0
    [_, ..rest] -> 1 + list_length(rest)
  }
}
