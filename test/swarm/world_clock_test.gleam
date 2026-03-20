import gleam/erlang/process
import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/agent/agent.{AgentConfig}
import zeitgeist/agent/types.{
  GovernmentAgent, HeadOfState, Reactive, default_personality,
}
import zeitgeist/swarm/platform
import zeitgeist/swarm/registry
import zeitgeist/swarm/world_clock.{ClockConfig}

pub fn main() {
  gleeunit.main()
}

pub fn clock_advances_ticks_test() {
  let assert Ok(reg) = registry.start("clock_test_reg1")
  let assert Ok(plat) = platform.start("clock_test_world1")

  // Start 1 agent
  let personality = default_personality()
  let config =
    AgentConfig(
      id: "clock_agent1",
      world_id: "clock_test_world1",
      kind: GovernmentAgent(country: "usa", role: HeadOfState, tier: Reactive),
      personality: personality,
      tier: Reactive,
      registry: reg,
      platform: plat,
      graph: None,
      llm_pool: None,
    )
  let assert Ok(_agent) = agent.start(config)

  // Start clock with 50ms interval, 5 max ticks
  let clock_cfg =
    ClockConfig(
      world_id: "clock_test_world1",
      tick_interval_ms: 50,
      max_ticks: 5,
      registry: reg,
      world_tension: 0.5,
    )
  let assert Ok(clock) = world_clock.start(clock_cfg)

  // Wait 500ms — clock should complete 5 ticks
  process.sleep(500)

  let status = world_clock.get_status(clock)
  should.be_true(status.current_tick >= 3)

  world_clock.stop(clock)
  registry.stop(reg)
  platform.stop(plat)
}
