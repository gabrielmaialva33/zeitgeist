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

pub fn main() {
  gleeunit.main()
}

pub fn start_agent_test() {
  let assert Ok(reg) = registry.start("agent_test_reg1")
  let assert Ok(plat) = platform.start("agent_test_world1")

  let config =
    AgentConfig(
      id: "agent1",
      world_id: "agent_test_world1",
      kind: GovernmentAgent(country: "usa", role: HeadOfState, tier: Reactive),
      personality: default_personality(),
      tier: Reactive,
      registry: reg,
      platform: plat,
      graph: None,
      llm_pool: None,
    )

  let assert Ok(_agent) = agent.start(config)

  // Verify the agent registered itself
  let result = registry.lookup(reg, "agent_test_world1", "agent1")
  should.be_ok(result)

  registry.stop(reg)
  platform.stop(plat)
}

pub fn tick_produces_action_test() {
  let assert Ok(reg) = registry.start("agent_test_reg2")
  let assert Ok(plat) = platform.start("agent_test_world2")

  // Hawkish government agent — high tension will cause actions
  let personality =
    types.Personality(
      ..default_personality(),
      hawkishness: 0.9,
      extraversion: 0.9,
    )
  let config =
    AgentConfig(
      id: "hawk_agent",
      world_id: "agent_test_world2",
      kind: GovernmentAgent(country: "usa", role: HeadOfState, tier: Reactive),
      personality: personality,
      tier: Reactive,
      registry: reg,
      platform: plat,
      graph: None,
      llm_pool: None,
    )

  let assert Ok(a) = agent.start(config)

  // Send multiple ticks with high tension to ensure at least one activates
  agent.tick(a, 1, 12, 0.9)
  agent.tick(a, 2, 12, 0.9)
  agent.tick(a, 3, 12, 0.9)
  agent.tick(a, 4, 12, 0.9)
  agent.tick(a, 5, 12, 0.9)

  // Give actor time to process
  process.sleep(100)

  let health = agent.get_health(a)
  should.be_true(health.ticks_processed >= 1)

  registry.stop(reg)
  platform.stop(plat)
}
