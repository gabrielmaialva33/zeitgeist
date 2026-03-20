// Agent interview module — build interview prompts and send them via LLM pool.

import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import zeitgeist/agent/action
import zeitgeist/agent/memory.{type AgentMemory}
import zeitgeist/agent/types.{
  type AgentKind, type Personality, Citizen, CorporationAgent, GovernmentAgent,
  InfluencerAgent, JournalistAgent, MilitaryAgent, TraderAgent,
}
import zeitgeist/llm/pool.{type PoolMsg}
import zeitgeist/llm/types as llm_types

// ---------------------------------------------------------------------------
// Prompt building
// ---------------------------------------------------------------------------

/// Build an interview prompt for the agent. Pure function, exposed for testing.
pub fn build_prompt(
  agent_id: String,
  kind: AgentKind,
  personality: Personality,
  mem: AgentMemory,
  question: String,
) -> String {
  let role = kind_to_role(kind)
  let recent_actions = summarise_actions(mem.action_history)
  let sentiment_str = float.to_string(mem.current_sentiment)

  "=== AGENT INTERVIEW ===\n"
  <> "Agent ID: "
  <> agent_id
  <> "\n"
  <> "Role: "
  <> role
  <> "\n"
  <> "Personality:\n"
  <> "  openness="
  <> float.to_string(personality.openness)
  <> " conscientiousness="
  <> float.to_string(personality.conscientiousness)
  <> "\n"
  <> "  hawkishness="
  <> float.to_string(personality.hawkishness)
  <> " risk_appetite="
  <> float.to_string(personality.risk_appetite)
  <> "\n"
  <> "  agreeableness="
  <> float.to_string(personality.agreeableness)
  <> " neuroticism="
  <> float.to_string(personality.neuroticism)
  <> "\n"
  <> "Current Sentiment: "
  <> sentiment_str
  <> "\n"
  <> "Recent Actions:\n"
  <> recent_actions
  <> "\n"
  <> "Question: "
  <> question
  <> "\n"
  <> "=== ANSWER ==="
}

/// Call the LLM pool with an interview prompt.
/// Returns Ok(response_text) or Error(reason_string).
pub fn ask(
  llm_pool: Subject(PoolMsg),
  agent_id: String,
  kind: AgentKind,
  personality: Personality,
  mem: AgentMemory,
  question: String,
) -> Result(String, String) {
  let prompt = build_prompt(agent_id, kind, personality, mem, question)
  let req = llm_types.new_request(prompt, llm_types.MockProvider)
  case pool.complete(llm_pool, req) {
    Ok(resp) -> Ok(resp.content)
    Error(e) -> Error(llm_error_to_string(e))
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn kind_to_role(kind: AgentKind) -> String {
  case kind {
    GovernmentAgent(country: c, role: r, tier: _) ->
      "Government official (" <> gov_role_name(r) <> ") of " <> c
    MilitaryAgent(country: c, branch: b, rank: rank) ->
      "Military officer rank "
      <> int.to_string(rank)
      <> " ("
      <> military_branch_name(b)
      <> ") of "
      <> c
    CorporationAgent(company: co, sector: s, market_cap: _) ->
      "Corporate agent at " <> co <> " in " <> s <> " sector"
    TraderAgent(firm: f, style: st) ->
      "Trader at " <> f <> " with " <> trading_style_name(st) <> " style"
    JournalistAgent(outlet: o, reach: r) ->
      "Journalist at " <> o <> " (reach: " <> int.to_string(r) <> ")"
    InfluencerAgent(platform: p, followers: f) ->
      "Influencer on " <> p <> " (" <> int.to_string(f) <> " followers)"
    Citizen(demographics: d) ->
      "Citizen (age: "
      <> age_range_name(d.age_range)
      <> ", education: "
      <> education_name(d.education)
      <> ")"
  }
}

fn summarise_actions(
  history: List(#(Int, action.AgentActionType)),
) -> String {
  let recent = list.take(history, 5)
  case recent {
    [] -> "  (no recent actions)\n"
    _ ->
      list.map(recent, fn(entry) {
        let #(tick, act) = entry
        "  tick=" <> int.to_string(tick) <> ": " <> action_name(act) <> "\n"
      })
      |> string.join("")
  }
}

fn action_name(act: action.AgentActionType) -> String {
  case act {
    action.DiplomaticMessage(to: t, ..) -> "DiplomaticMessage -> " <> t
    action.IssueSanction(target_country: t, ..) -> "IssueSanction -> " <> t
    action.FormAlliance(target_country: t) -> "FormAlliance -> " <> t
    action.MilitaryAction(target: t, ..) -> "MilitaryAction -> " <> t
    action.CreatePost(platform: p, ..) -> "CreatePost on " <> p
    action.MarketBuy(symbol: s, ..) -> "MarketBuy " <> s
    action.MarketSell(symbol: s, ..) -> "MarketSell " <> s
    action.DoNothing -> "DoNothing"
    action.ObserveAndWait -> "ObserveAndWait"
  }
}

fn gov_role_name(role: types.GovRole) -> String {
  case role {
    types.HeadOfState -> "Head of State"
    types.ForeignMinister -> "Foreign Minister"
    types.DefenseMinister -> "Defense Minister"
    types.Ambassador -> "Ambassador"
  }
}

fn military_branch_name(branch: types.MilitaryBranch) -> String {
  case branch {
    types.Army -> "Army"
    types.Navy -> "Navy"
    types.AirForce -> "Air Force"
    types.Intelligence -> "Intelligence"
  }
}

fn trading_style_name(style: types.TradingStyle) -> String {
  case style {
    types.Conservative -> "conservative"
    types.Moderate -> "moderate"
    types.Aggressive -> "aggressive"
  }
}

fn age_range_name(age: types.AgeRange) -> String {
  case age {
    types.Youth -> "youth"
    types.Adult -> "adult"
    types.Senior -> "senior"
  }
}

fn education_name(edu: types.EducationLevel) -> String {
  case edu {
    types.Primary -> "primary"
    types.Secondary -> "secondary"
    types.Tertiary -> "tertiary"
    types.PostGraduate -> "postgraduate"
  }
}

fn llm_error_to_string(err: llm_types.LlmError) -> String {
  case err {
    llm_types.LlmNetworkError(p, r) -> "network_error(" <> p <> "): " <> r
    llm_types.LlmParseError(p, _) -> "parse_error(" <> p <> ")"
    llm_types.LlmTimeout(p, t) ->
      "timeout(" <> p <> "): " <> int.to_string(t) <> "ms"
    llm_types.LlmRateLimited(p, _) -> "rate_limited(" <> p <> ")"
    llm_types.LlmUnknownError(p, r) -> "unknown_error(" <> p <> "): " <> r
    llm_types.AllProvidersFailed(pr, fb) -> "all_failed: " <> pr <> " / " <> fb
  }
}
