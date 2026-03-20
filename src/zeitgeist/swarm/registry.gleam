import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import gleam/string
import zeitgeist/core/ets

pub type RegistryMsg {
  Register(world_id: String, agent_id: String, subject: Subject(Dynamic))
  Unregister(world_id: String, agent_id: String)
  Lookup(
    world_id: String,
    agent_id: String,
    reply_to: Subject(Result(Subject(Dynamic), Nil)),
  )
  ListWorldAgents(world_id: String, reply_to: Subject(List(String)))
  RegistryStop
}

type RegistryState {
  RegistryState(
    table: ets.EtsTable,
    world_agents: Dict(String, List(String)),
  )
}

@external(erlang, "zeitgeist_ets_ffi", "identity")
fn coerce(a: a) -> b

pub fn start(prefix: String) -> Result(Subject(RegistryMsg), actor.StartError) {
  let table_name = string.append(prefix, "_registry_subjects")
  let assert Ok(table) = ets.new(table_name, "set")
  let init_state =
    RegistryState(table: table, world_agents: dict.new())
  let r =
    actor.new(init_state)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn register(
  reg: Subject(RegistryMsg),
  world_id: String,
  agent_id: String,
  subject: Subject(Dynamic),
) -> Nil {
  process.send(reg, Register(world_id, agent_id, subject))
}

pub fn unregister(
  reg: Subject(RegistryMsg),
  world_id: String,
  agent_id: String,
) -> Nil {
  process.send(reg, Unregister(world_id, agent_id))
}

pub fn lookup(
  reg: Subject(RegistryMsg),
  world_id: String,
  agent_id: String,
) -> Result(Subject(Dynamic), Nil) {
  process.call(reg, waiting: 5000, sending: fn(reply_to) {
    Lookup(world_id, agent_id, reply_to)
  })
}

pub fn list_world_agents(
  reg: Subject(RegistryMsg),
  world_id: String,
) -> List(String) {
  process.call(reg, waiting: 5000, sending: fn(reply_to) {
    ListWorldAgents(world_id, reply_to)
  })
}

pub fn stop(reg: Subject(RegistryMsg)) -> Nil {
  process.send(reg, RegistryStop)
}

fn handle_message(
  state: RegistryState,
  msg: RegistryMsg,
) -> actor.Next(RegistryState, RegistryMsg) {
  case msg {
    Register(world_id, agent_id, subject) -> {
      let key = world_id <> ":" <> agent_id
      let dyn_subject: Dynamic = coerce(subject)
      ets.insert(state.table, key, dyn_subject)
      let current_agents =
        dict.get(state.world_agents, world_id)
        |> unwrap_or([])
      let updated_agents = case list.contains(current_agents, agent_id) {
        True -> current_agents
        False -> [agent_id, ..current_agents]
      }
      let new_world_agents =
        dict.insert(state.world_agents, world_id, updated_agents)
      actor.continue(RegistryState(..state, world_agents: new_world_agents))
    }

    Unregister(world_id, agent_id) -> {
      let key = world_id <> ":" <> agent_id
      ets.delete_key(state.table, key)
      let current_agents =
        dict.get(state.world_agents, world_id)
        |> unwrap_or([])
      let updated_agents = list.filter(current_agents, fn(a) { a != agent_id })
      let new_world_agents =
        dict.insert(state.world_agents, world_id, updated_agents)
      actor.continue(RegistryState(..state, world_agents: new_world_agents))
    }

    Lookup(world_id, agent_id, reply_to) -> {
      let key = world_id <> ":" <> agent_id
      let result =
        ets.lookup(state.table, key)
        |> result_map(fn(dyn) { coerce(dyn) })
      process.send(reply_to, result)
      actor.continue(state)
    }

    ListWorldAgents(world_id, reply_to) -> {
      let agents =
        dict.get(state.world_agents, world_id)
        |> unwrap_or([])
      process.send(reply_to, agents)
      actor.continue(state)
    }

    RegistryStop -> actor.stop()
  }
}

fn unwrap_or(result: Result(a, e), default: a) -> a {
  case result {
    Ok(v) -> v
    Error(_) -> default
  }
}

fn result_map(result: Result(a, e), f: fn(a) -> b) -> Result(b, e) {
  case result {
    Ok(v) -> Ok(f(v))
    Error(e) -> Error(e)
  }
}
