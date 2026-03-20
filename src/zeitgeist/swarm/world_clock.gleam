import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import zeitgeist/agent/agent.{type AgentMsg}
import zeitgeist/agent/types
import zeitgeist/swarm/registry.{type RegistryMsg}

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

pub type ClockConfig {
  ClockConfig(
    world_id: String,
    tick_interval_ms: Int,
    max_ticks: Int,
    registry: Subject(RegistryMsg),
    world_tension: Float,
  )
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

pub type ClockMsg {
  SetSelf(subject: Subject(ClockMsg))
  DoTick
  GetStatus(reply_to: Subject(ClockStatus))
  ClockStop
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

pub type ClockStatus {
  ClockStatus(
    world_id: String,
    current_tick: Int,
    state: types.WorldState,
    max_ticks: Int,
  )
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

type ClockState {
  ClockState(
    config: ClockConfig,
    current_tick: Int,
    state: types.WorldState,
    self_subject: Option(Subject(ClockMsg)),
  )
}

// ---------------------------------------------------------------------------
// FFI — coerce Dynamic subject to typed subject
// ---------------------------------------------------------------------------

@external(erlang, "zeitgeist_ets_ffi", "identity")
fn coerce(a: a) -> b

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn start(
  config: ClockConfig,
) -> Result(Subject(ClockMsg), actor.StartError) {
  let init_state =
    ClockState(
      config: config,
      current_tick: 0,
      state: types.Running,
      self_subject: None,
    )
  let r =
    actor.new(init_state)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> {
      // Send self-reference and schedule first tick
      process.send(started.data, SetSelf(started.data))
      process.send_after(started.data, config.tick_interval_ms, DoTick)
      Ok(started.data)
    }
    Error(e) -> Error(e)
  }
}

pub fn get_status(clock: Subject(ClockMsg)) -> ClockStatus {
  process.call(clock, waiting: 5000, sending: fn(reply_to) {
    GetStatus(reply_to)
  })
}

pub fn stop(clock: Subject(ClockMsg)) -> Nil {
  process.send(clock, ClockStop)
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

fn handle_message(
  state: ClockState,
  msg: ClockMsg,
) -> actor.Next(ClockState, ClockMsg) {
  case msg {
    SetSelf(subject) ->
      actor.continue(ClockState(..state, self_subject: Some(subject)))

    DoTick -> {
      let new_tick = state.current_tick + 1
      // Notify all agents in this world
      let agent_ids = registry.list_world_agents(state.config.registry, state.config.world_id)
      let simulated_hour = new_tick % 24
      list.each(agent_ids, fn(agent_id) {
        let result =
          registry.lookup(state.config.registry, state.config.world_id, agent_id)
        case result {
          Ok(dyn_subject) -> {
            let agent_subject: Subject(AgentMsg) = coerce(dyn_subject)
            agent.tick(
              agent_subject,
              new_tick,
              simulated_hour,
              state.config.world_tension,
            )
          }
          Error(_) -> Nil
        }
      })
      // Decide if simulation is done or schedule next tick
      let new_world_state = case new_tick >= state.config.max_ticks {
        True -> types.Completed
        False -> types.Running
      }
      case new_world_state {
        types.Running -> {
          case state.self_subject {
            Some(self) -> {
              let _ =
                process.send_after(self, state.config.tick_interval_ms, DoTick)
              Nil
            }
            None -> Nil
          }
        }
        _ -> Nil
      }
      actor.continue(
        ClockState(..state, current_tick: new_tick, state: new_world_state),
      )
    }

    GetStatus(reply_to) -> {
      let status =
        ClockStatus(
          world_id: state.config.world_id,
          current_tick: state.current_tick,
          state: state.state,
          max_ticks: state.config.max_ticks,
        )
      process.send(reply_to, status)
      actor.continue(state)
    }

    ClockStop -> actor.stop()
  }
}
