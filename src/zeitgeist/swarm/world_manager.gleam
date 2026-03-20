import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/otp/actor
import zeitgeist/agent/agent.{AgentConfig}
import zeitgeist/agent/types.{type AgentKind, type Personality, Reactive}
import zeitgeist/swarm/platform
import zeitgeist/swarm/registry.{type RegistryMsg}
import zeitgeist/swarm/world.{type World}
import zeitgeist/swarm/world_clock.{ClockConfig}

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub type AgentSpec {
  AgentSpec(
    id: String,
    kind: AgentKind,
    personality: Personality,
  )
}

pub type WorldCreateConfig {
  WorldCreateConfig(
    name: String,
    max_ticks: Int,
    tick_interval_ms: Int,
    agents: List(AgentSpec),
    world_tension: Float,
  )
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

pub type ManagerMsg {
  CreateWorld(
    config: WorldCreateConfig,
    reply_to: Subject(Result(World, String)),
  )
  ListWorlds(reply_to: Subject(List(World)))
  GetWorld(world_id: String, reply_to: Subject(Result(World, Nil)))
  StopWorld(world_id: String)
  ManagerStop
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

type ManagerState {
  ManagerState(
    registry: Subject(RegistryMsg),
    worlds: Dict(String, World),
    counter: Int,
  )
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn start(
  reg: Subject(RegistryMsg),
) -> Result(Subject(ManagerMsg), actor.StartError) {
  let init_state =
    ManagerState(registry: reg, worlds: dict.new(), counter: 0)
  let r =
    actor.new(init_state)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn create_world(
  mgr: Subject(ManagerMsg),
  config: WorldCreateConfig,
) -> Result(World, String) {
  process.call(mgr, waiting: 10_000, sending: fn(reply_to) {
    CreateWorld(config, reply_to)
  })
}

pub fn list_worlds(mgr: Subject(ManagerMsg)) -> List(World) {
  process.call(mgr, waiting: 5000, sending: fn(reply_to) {
    ListWorlds(reply_to)
  })
}

pub fn get_world(
  mgr: Subject(ManagerMsg),
  world_id: String,
) -> Result(World, Nil) {
  process.call(mgr, waiting: 5000, sending: fn(reply_to) {
    GetWorld(world_id, reply_to)
  })
}

pub fn stop(mgr: Subject(ManagerMsg)) -> Nil {
  process.send(mgr, ManagerStop)
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

fn handle_message(
  state: ManagerState,
  msg: ManagerMsg,
) -> actor.Next(ManagerState, ManagerMsg) {
  case msg {
    CreateWorld(config: cfg, reply_to: reply_to) -> {
      let counter = state.counter + 1
      let world_id = "world_" <> int.to_string(counter)

      // Start platform for this world
      let plat_result = platform.start(world_id)
      case plat_result {
        Error(_) -> {
          process.send(reply_to, Error("Failed to start platform"))
          actor.continue(ManagerState(..state, counter: counter))
        }
        Ok(plat) -> {
          // Start all agents
          let agent_ids =
            list.map(cfg.agents, fn(spec) {
              let agent_cfg =
                AgentConfig(
                  id: spec.id,
                  world_id: world_id,
                  kind: spec.kind,
                  personality: spec.personality,
                  tier: Reactive,
                  registry: state.registry,
                  platform: plat,
                )
              let _result = agent.start(agent_cfg)
              spec.id
            })

          // Start WorldClock
          let clock_cfg =
            ClockConfig(
              world_id: world_id,
              tick_interval_ms: cfg.tick_interval_ms,
              max_ticks: cfg.max_ticks,
              registry: state.registry,
              world_tension: cfg.world_tension,
            )
          let _clock_result = world_clock.start(clock_cfg)

          // Build World record
          let w =
            world.World(
              id: world_id,
              name: cfg.name,
              seed_events: [],
              tick: 0,
              tick_interval_ms: cfg.tick_interval_ms,
              agent_ids: agent_ids,
              state: types.Running,
              max_ticks: cfg.max_ticks,
              world_tension: cfg.world_tension,
            )

          let new_worlds = dict.insert(state.worlds, world_id, w)
          process.send(reply_to, Ok(w))
          actor.continue(
            ManagerState(..state, worlds: new_worlds, counter: counter),
          )
        }
      }
    }

    ListWorlds(reply_to) -> {
      let worlds = dict.values(state.worlds)
      process.send(reply_to, worlds)
      actor.continue(state)
    }

    GetWorld(world_id, reply_to) -> {
      let result = dict.get(state.worlds, world_id)
      process.send(reply_to, result)
      actor.continue(state)
    }

    StopWorld(_world_id) -> {
      // For P2: just acknowledge (agents self-manage)
      actor.continue(state)
    }

    ManagerStop -> actor.stop()
  }
}
