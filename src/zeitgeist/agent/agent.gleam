import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import zeitgeist/agent/action.{
  type AgentActionType, DiplomaticMessage, FormAlliance, IssueSanction,
  MilitaryAction,
}
import zeitgeist/agent/decision
import zeitgeist/agent/interview
import zeitgeist/agent/memory.{type AgentMemory}
import zeitgeist/agent/types.{type AgentKind, type AgentTier, type Personality}
import zeitgeist/graph/store.{type GraphMsg}
import zeitgeist/llm/pool.{type PoolMsg}
import zeitgeist/swarm/kg_feedback
import zeitgeist/swarm/platform.{type PlatformMsg}
import zeitgeist/swarm/registry.{type RegistryMsg}

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

pub type AgentConfig {
  AgentConfig(
    id: String,
    world_id: String,
    kind: AgentKind,
    personality: Personality,
    tier: AgentTier,
    registry: Subject(RegistryMsg),
    platform: Subject(PlatformMsg),
    graph: Option(Subject(GraphMsg)),
    llm_pool: Option(Subject(PoolMsg)),
  )
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

pub type AgentMsg {
  Tick(tick: Int, simulated_hour: Int, world_tension: Float)
  GetHealth(reply_to: Subject(AgentHealth))
  Interview(question: String, reply_to: Subject(String))
  AgentStop
}

// ---------------------------------------------------------------------------
// Health
// ---------------------------------------------------------------------------

pub type AgentHealth {
  AgentHealth(
    id: String,
    ticks_processed: Int,
    actions_taken: Int,
    sentiment: Float,
  )
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

type AgentState {
  AgentState(
    config: AgentConfig,
    memory: AgentMemory,
    ticks_processed: Int,
    actions_taken: Int,
  )
}

// ---------------------------------------------------------------------------
// FFI
// ---------------------------------------------------------------------------

@external(erlang, "erlang", "float")
fn int_to_float(n: Int) -> Float

@external(erlang, "zeitgeist_ets_ffi", "identity")
fn coerce(a: a) -> b

@external(erlang, "zeitgeist_ets_ffi", "now_ms")
fn now_ms() -> Int

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn start(config: AgentConfig) -> Result(Subject(AgentMsg), actor.StartError) {
  let init_state =
    AgentState(
      config: config,
      memory: memory.new(100),
      ticks_processed: 0,
      actions_taken: 0,
    )
  let r =
    actor.new(init_state)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> {
      // Register self in registry
      let dyn_subject: Subject(Dynamic) = coerce(started.data)
      registry.register(
        config.registry,
        config.world_id,
        config.id,
        dyn_subject,
      )
      Ok(started.data)
    }
    Error(e) -> Error(e)
  }
}

pub fn stop(agent: Subject(AgentMsg)) -> Nil {
  process.send(agent, AgentStop)
}

pub fn tick(
  agent: Subject(AgentMsg),
  tick_num: Int,
  hour: Int,
  tension: Float,
) -> Nil {
  process.send(
    agent,
    Tick(tick: tick_num, simulated_hour: hour, world_tension: tension),
  )
}

pub fn get_health(agent: Subject(AgentMsg)) -> AgentHealth {
  process.call(agent, waiting: 5000, sending: fn(reply_to) {
    GetHealth(reply_to)
  })
}

/// Ask an agent a question. Returns the LLM response or a fallback string.
/// Timeout: 30 seconds.
pub fn interview_agent(agent: Subject(AgentMsg), question: String) -> String {
  process.call(agent, waiting: 30_000, sending: fn(reply_to) {
    Interview(question: question, reply_to: reply_to)
  })
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

fn handle_message(
  state: AgentState,
  msg: AgentMsg,
) -> actor.Next(AgentState, AgentMsg) {
  case msg {
    Tick(tick: tick_num, simulated_hour: hour, world_tension: tension) -> {
      let probability =
        decision.activation_probability(state.config.personality, hour, False)
      // Deterministic activation check
      let hash = tick_num * 2_654_435_761 % 1000
      let hash_f = int_to_float(hash) /. 1000.0
      let new_state = case hash_f <. probability {
        True -> {
          let ctx =
            decision.DecisionContext(
              tick: tick_num,
              simulated_hour: hour,
              recent_events_count: 0,
              world_tension: tension,
            )
          let action =
            decision.decide_reactive(
              state.config.kind,
              state.config.personality,
              state.memory,
              ctx,
            )
          execute_action(state.config, action, tick_num)
          // KG feedback: record action to graph if configured
          case state.config.graph {
            Some(graph_subj) ->
              kg_feedback.record_to_graph(
                graph_subj,
                state.config.id,
                state.config.world_id,
                action,
                now_ms(),
              )
            None -> Nil
          }
          let new_mem = memory.record_action(state.memory, tick_num, action)
          AgentState(
            ..state,
            memory: new_mem,
            ticks_processed: state.ticks_processed + 1,
            actions_taken: state.actions_taken + 1,
          )
        }
        False -> AgentState(..state, ticks_processed: state.ticks_processed + 1)
      }
      actor.continue(new_state)
    }

    GetHealth(reply_to) -> {
      let health =
        AgentHealth(
          id: state.config.id,
          ticks_processed: state.ticks_processed,
          actions_taken: state.actions_taken,
          sentiment: memory.sentiment(state.memory),
        )
      process.send(reply_to, health)
      actor.continue(state)
    }

    Interview(question: q, reply_to: reply_to) -> {
      let response = case state.config.llm_pool {
        Some(pool) ->
          case
            interview.ask(
              pool,
              state.config.id,
              state.config.kind,
              state.config.personality,
              state.memory,
              q,
            )
          {
            Ok(answer) -> answer
            Error(e) -> "Interview error: " <> e
          }
        None ->
          interview.build_prompt(
            state.config.id,
            state.config.kind,
            state.config.personality,
            state.memory,
            q,
          )
      }
      process.send(reply_to, response)
      actor.continue(state)
    }

    AgentStop -> actor.stop()
  }
}

// ---------------------------------------------------------------------------
// Execute action
// ---------------------------------------------------------------------------

fn execute_action(
  config: AgentConfig,
  action: AgentActionType,
  tick_num: Int,
) -> Nil {
  case action {
    DiplomaticMessage(to: to, content: content, public: is_public) -> {
      let msg =
        platform.DiplomaticMsg(
          from: config.id,
          to: to,
          content: content,
          public: is_public,
          tick: tick_num,
        )
      platform.send_message(config.platform, msg)
    }

    IssueSanction(target_country: target, severity: _sev) -> {
      let msg =
        platform.DiplomaticMsg(
          from: config.id,
          to: target,
          content: "Sanction issued",
          public: True,
          tick: tick_num,
        )
      platform.send_message(config.platform, msg)
    }

    MilitaryAction(action: _kind, target: target) -> {
      let msg =
        platform.DiplomaticMsg(
          from: config.id,
          to: target,
          content: "Military action",
          public: False,
          tick: tick_num,
        )
      platform.send_message(config.platform, msg)
    }

    FormAlliance(target_country: target) -> {
      let msg =
        platform.DiplomaticMsg(
          from: config.id,
          to: target,
          content: "Alliance proposed",
          public: True,
          tick: tick_num,
        )
      platform.send_message(config.platform, msg)
    }

    _ -> Nil
  }
}
