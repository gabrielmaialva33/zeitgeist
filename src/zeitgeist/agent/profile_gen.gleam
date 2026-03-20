// Agent profile generation — gathers KG context, builds LLM prompt, returns profile
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/string
import zeitgeist/agent/types.{type AgentKind, type Personality}
import zeitgeist/graph/fact.{type AtomicFact}
import zeitgeist/graph/store.{type GraphMsg}
import zeitgeist/llm/pool.{type PoolMsg}
import zeitgeist/llm/types as llm_types

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

pub type AgentProfile {
  AgentProfile(
    id: String,
    kind: AgentKind,
    personality: Personality,
    bio: String,
    persona: String,
  )
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Generate an agent profile using the KG for context and LLM for persona.
pub fn generate_profile(
  llm: Subject(PoolMsg),
  graph: Subject(GraphMsg),
  agent_id: String,
  kind: AgentKind,
  personality: Personality,
) -> Result(AgentProfile, String) {
  // Gather facts from knowledge graph
  let facts = store.get_facts_by_entity(graph, agent_id)

  // Build context from facts
  let context_str = facts_to_context(facts)

  // Build the prompt
  let kind_str = agent_kind_to_string(kind)
  let personality_str = personality_summary(personality)

  let prompt =
    "Generate a concise agent profile for a "
    <> kind_str
    <> " agent with ID '"
    <> agent_id
    <> "'.\n"
    <> "Personality traits: "
    <> personality_str
    <> "\n"
    <> case string.length(context_str) > 0 {
      True -> "Known facts: " <> context_str <> "\n"
      False -> ""
    }
    <> "Respond with: BIO: <1-2 sentence biography>. PERSONA: <behavioral persona description>."

  let req =
    llm_types.LlmRequest(
      prompt: prompt,
      system: "You are a geopolitical intelligence analyst creating agent personas.",
      provider: llm_types.MockProvider,
      max_tokens: 256,
      temperature: 0.7,
      priority: llm_types.Normal,
    )

  case pool.complete(llm, req) {
    Ok(resp) -> {
      let #(bio, persona) = parse_profile_response(resp.content, agent_id)
      Ok(AgentProfile(
        id: agent_id,
        kind: kind,
        personality: personality,
        bio: bio,
        persona: persona,
      ))
    }
    Error(err) -> Error("LLM error: " <> llm_error_to_string(err))
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn facts_to_context(facts: List(AtomicFact)) -> String {
  case facts {
    [] -> ""
    _ ->
      facts
      |> list.take(5)
      |> list.map(fn(f) { f.subject <> " " <> f.object })
      |> string.join(", ")
  }
}

fn agent_kind_to_string(kind: AgentKind) -> String {
  case kind {
    types.Citizen(_) -> "citizen"
    types.GovernmentAgent(country, role, _) ->
      gov_role_to_string(role) <> " from " <> country
    types.MilitaryAgent(country, branch, _) ->
      military_branch_to_string(branch) <> " officer from " <> country
    types.CorporationAgent(company, sector, _) ->
      sector <> " executive at " <> company
    types.TraderAgent(firm, style) ->
      trading_style_to_string(style) <> " trader at " <> firm
    types.JournalistAgent(outlet, _) -> "journalist at " <> outlet
    types.InfluencerAgent(platform, _) -> "influencer on " <> platform
  }
}

fn gov_role_to_string(role: types.GovRole) -> String {
  case role {
    types.HeadOfState -> "head of state"
    types.ForeignMinister -> "foreign minister"
    types.DefenseMinister -> "defense minister"
    types.Ambassador -> "ambassador"
  }
}

fn military_branch_to_string(branch: types.MilitaryBranch) -> String {
  case branch {
    types.Army -> "army"
    types.Navy -> "navy"
    types.AirForce -> "air force"
    types.Intelligence -> "intelligence"
  }
}

fn trading_style_to_string(style: types.TradingStyle) -> String {
  case style {
    types.Conservative -> "conservative"
    types.Moderate -> "moderate"
    types.Aggressive -> "aggressive"
  }
}

fn personality_summary(p: Personality) -> String {
  "openness="
  <> float_to_str(p.openness)
  <> ", hawkishness="
  <> float_to_str(p.hawkishness)
  <> ", risk_appetite="
  <> float_to_str(p.risk_appetite)
}

fn float_to_str(f: Float) -> String {
  float_to_binary(f)
}

fn parse_profile_response(content: String, agent_id: String) -> #(String, String) {
  // Try to extract BIO: and PERSONA: sections
  let bio = case string.split(content, "BIO:") {
    [_, rest, ..] -> {
      case string.split(rest, "PERSONA:") {
        [bio_part, ..] -> string.trim(bio_part)
        [] -> string.trim(rest)
      }
    }
    _ -> "Agent " <> agent_id <> " — profile generated."
  }

  let persona = case string.split(content, "PERSONA:") {
    [_, rest, ..] -> string.trim(rest)
    _ -> "Analytical, measured, context-aware decision maker."
  }

  #(bio, persona)
}

fn llm_error_to_string(err: llm_types.LlmError) -> String {
  case err {
    llm_types.LlmNetworkError(p, r) -> "network(" <> p <> "): " <> r
    llm_types.LlmParseError(p, _) -> "parse(" <> p <> ")"
    llm_types.LlmTimeout(p, _) -> "timeout(" <> p <> ")"
    llm_types.LlmRateLimited(p, _) -> "rate_limited(" <> p <> ")"
    llm_types.LlmUnknownError(p, r) -> "unknown(" <> p <> "): " <> r
    llm_types.AllProvidersFailed(primary, fallback) ->
      "all_failed: " <> primary <> " / " <> fallback
  }
}

@external(erlang, "erlang", "float_to_binary")
fn float_to_binary(f: Float) -> String
