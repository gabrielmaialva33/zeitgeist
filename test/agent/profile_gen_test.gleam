import gleeunit
import gleeunit/should
import zeitgeist/agent/profile_gen
import zeitgeist/agent/types
import zeitgeist/graph/store
import zeitgeist/llm/pool
import zeitgeist/llm/types as llm_types

pub fn main() {
  gleeunit.main()
}

pub fn generate_profile_mock_llm_test() {
  // Start mock LLM pool
  let cfg =
    pool.PoolConfig(
      default_provider: llm_types.MockProvider,
      fallback_provider: llm_types.MockProvider,
      max_concurrent: 2,
    )
  let assert Ok(llm) = pool.start(cfg)

  // Start empty graph
  let assert Ok(graph) = store.start("profile_gen_test_1")

  let personality = types.default_personality()
  let kind =
    types.GovernmentAgent(
      country: "usa",
      role: types.Ambassador,
      tier: types.Standard,
    )

  let result =
    profile_gen.generate_profile(llm, graph, "agent_usa_001", kind, personality)

  result |> should.be_ok

  let assert Ok(profile) = result
  profile.id |> should.equal("agent_usa_001")

  // Bio and persona should be non-empty strings
  let assert True = string_length(profile.bio) > 0
  let assert True = string_length(profile.persona) > 0

  store.stop(graph)
  pool.stop(llm)
}

pub fn generate_profile_journalist_test() {
  let cfg =
    pool.PoolConfig(
      default_provider: llm_types.MockProvider,
      fallback_provider: llm_types.MockProvider,
      max_concurrent: 2,
    )
  let assert Ok(llm) = pool.start(cfg)
  let assert Ok(graph) = store.start("profile_gen_test_2")

  let personality = types.default_personality()
  let kind = types.JournalistAgent(outlet: "reuters", reach: 5_000_000)

  let result =
    profile_gen.generate_profile(llm, graph, "reporter_001", kind, personality)

  result |> should.be_ok

  let assert Ok(profile) = result
  profile.id |> should.equal("reporter_001")

  store.stop(graph)
  pool.stop(llm)
}

pub fn generate_profile_trader_test() {
  let cfg =
    pool.PoolConfig(
      default_provider: llm_types.MockProvider,
      fallback_provider: llm_types.MockProvider,
      max_concurrent: 2,
    )
  let assert Ok(llm) = pool.start(cfg)
  let assert Ok(graph) = store.start("profile_gen_test_3")

  let personality =
    types.Personality(
      ..types.default_personality(),
      risk_appetite: 0.9,
      hawkishness: 0.3,
    )
  let kind = types.TraderAgent(firm: "citadel", style: types.Aggressive)

  let result =
    profile_gen.generate_profile(llm, graph, "trader_001", kind, personality)

  result |> should.be_ok
  let assert Ok(profile) = result
  profile.id |> should.equal("trader_001")

  store.stop(graph)
  pool.stop(llm)
}

@external(erlang, "string", "length")
fn string_length(s: String) -> Int
