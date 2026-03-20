import gleam/dynamic.{type Dynamic}
import gleam/erlang/process
import gleeunit
import gleeunit/should
import zeitgeist/swarm/registry

pub fn main() {
  gleeunit.main()
}

@external(erlang, "zeitgeist_ets_ffi", "identity")
fn coerce(a: a) -> b

pub fn register_and_lookup_test() {
  let assert Ok(reg) = registry.start("reg_test1")
  let subj: process.Subject(Dynamic) = coerce(process.new_subject())

  registry.register(reg, "world1", "agent1", subj)
  let result = registry.lookup(reg, "world1", "agent1")
  should.be_ok(result)

  registry.stop(reg)
}

pub fn lookup_missing_returns_error_test() {
  let assert Ok(reg) = registry.start("reg_test2")

  let result = registry.lookup(reg, "world1", "missing_agent")
  should.be_error(result)

  registry.stop(reg)
}

pub fn list_agents_in_world_test() {
  let assert Ok(reg) = registry.start("reg_test3")
  let s1: process.Subject(Dynamic) = coerce(process.new_subject())
  let s2: process.Subject(Dynamic) = coerce(process.new_subject())
  let s3: process.Subject(Dynamic) = coerce(process.new_subject())

  registry.register(reg, "w1", "agent1", s1)
  registry.register(reg, "w1", "agent2", s2)
  registry.register(reg, "w2", "agent3", s3)

  let agents_w1 = registry.list_world_agents(reg, "w1")
  should.equal(2, list_length(agents_w1))

  let agents_w2 = registry.list_world_agents(reg, "w2")
  should.equal(1, list_length(agents_w2))

  registry.stop(reg)
}

pub fn unregister_test() {
  let assert Ok(reg) = registry.start("reg_test4")
  let subj: process.Subject(Dynamic) = coerce(process.new_subject())

  registry.register(reg, "world1", "agent1", subj)
  let r1 = registry.lookup(reg, "world1", "agent1")
  should.be_ok(r1)

  registry.unregister(reg, "world1", "agent1")
  let r2 = registry.lookup(reg, "world1", "agent1")
  should.be_error(r2)

  registry.stop(reg)
}

fn list_length(lst: List(a)) -> Int {
  case lst {
    [] -> 0
    [_, ..rest] -> 1 + list_length(rest)
  }
}
