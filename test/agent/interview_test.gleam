import gleam/string
import gleeunit
import gleeunit/should
import zeitgeist/agent/interview
import zeitgeist/agent/memory
import zeitgeist/agent/types.{
  GovernmentAgent, HeadOfState, Reactive, default_personality,
}
import zeitgeist/llm/pool
import zeitgeist/llm/types as llm_types

pub fn main() {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// Prompt building
// ---------------------------------------------------------------------------

pub fn build_prompt_contains_agent_id_test() {
  let mem = memory.new(10)
  let kind = GovernmentAgent(country: "usa", role: HeadOfState, tier: Reactive)
  let prompt =
    interview.build_prompt("agent_001", kind, default_personality(), mem, "What is your stance?")
  should.be_true(string.contains(prompt, "agent_001"))
}

pub fn build_prompt_contains_role_test() {
  let mem = memory.new(10)
  let kind = GovernmentAgent(country: "usa", role: HeadOfState, tier: Reactive)
  let prompt =
    interview.build_prompt("test_agent", kind, default_personality(), mem, "What next?")
  should.be_true(string.contains(prompt, "usa"))
  should.be_true(string.contains(prompt, "Head of State"))
}

pub fn build_prompt_contains_personality_stats_test() {
  let mem = memory.new(10)
  let kind = GovernmentAgent(country: "cn", role: HeadOfState, tier: Reactive)
  let personality = default_personality()
  let prompt =
    interview.build_prompt("agent_cn", kind, personality, mem, "Outlook?")
  should.be_true(string.contains(prompt, "hawkishness"))
  should.be_true(string.contains(prompt, "risk_appetite"))
  should.be_true(string.contains(prompt, "openness"))
}

pub fn build_prompt_contains_question_test() {
  let mem = memory.new(10)
  let kind = GovernmentAgent(country: "uk", role: HeadOfState, tier: Reactive)
  let q = "How will you respond to the trade dispute?"
  let prompt = interview.build_prompt("agent_uk", kind, default_personality(), mem, q)
  should.be_true(string.contains(prompt, q))
}

pub fn build_prompt_shows_no_recent_actions_when_empty_test() {
  let mem = memory.new(10)
  let kind = GovernmentAgent(country: "de", role: HeadOfState, tier: Reactive)
  let prompt =
    interview.build_prompt("agent_de", kind, default_personality(), mem, "Plans?")
  should.be_true(string.contains(prompt, "no recent actions"))
}

// ---------------------------------------------------------------------------
// ask() with mock LLM
// ---------------------------------------------------------------------------

pub fn ask_returns_response_with_mock_llm_test() {
  let assert Ok(pool_subj) =
    pool.start(pool.PoolConfig(
      default_provider: llm_types.MockProvider,
      fallback_provider: llm_types.MockProvider,
      max_concurrent: 2,
    ))
  let mem = memory.new(10)
  let kind = GovernmentAgent(country: "usa", role: HeadOfState, tier: Reactive)
  let result =
    interview.ask(
      pool_subj,
      "agent_usa",
      kind,
      default_personality(),
      mem,
      "What is your foreign policy priority?",
    )
  should.be_ok(result)
  let assert Ok(response) = result
  // Mock LLM returns non-empty content
  should.be_true(string.length(response) > 0)
  pool.stop(pool_subj)
}
