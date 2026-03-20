import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import zeitgeist/core/entity
import zeitgeist/graph/fact.{type AtomicFact}
import zeitgeist/graph/store.{type GraphMsg}
import zeitgeist/risk/cii
import zeitgeist/risk/cii_server.{type CiiMsg}
import zeitgeist/swarm/registry.{type RegistryMsg}

// ---------------------------------------------------------------------------
// ReACT Step types
// ---------------------------------------------------------------------------

pub type ReActStep {
  Thought(content: String)
  Action(tool: ReActTool)
  Observation(result: List(String))
}

// ---------------------------------------------------------------------------
// Tool types
// ---------------------------------------------------------------------------

pub type ReActTool {
  QueryGraphTool(entity_id: String)
  RiskSnapshotTool(country_code: String)
  InterviewAgentTool(world_id: String, agent_id: String)
}

// ---------------------------------------------------------------------------
// Tool context — optional subjects
// ---------------------------------------------------------------------------

pub type ToolContext {
  ToolContext(
    graph: Option(Subject(GraphMsg)),
    cii: Option(Subject(CiiMsg)),
    registry: Option(Subject(RegistryMsg)),
  )
}

pub fn empty_context() -> ToolContext {
  ToolContext(graph: None, cii: None, registry: None)
}

// ---------------------------------------------------------------------------
// Tool execution
// ---------------------------------------------------------------------------

pub fn execute_tool(tool: ReActTool, ctx: ToolContext) -> List(String) {
  case tool {
    QueryGraphTool(entity_id) -> execute_query_graph(entity_id, ctx)
    RiskSnapshotTool(country_code) -> execute_risk_snapshot(country_code, ctx)
    InterviewAgentTool(world_id, agent_id) ->
      execute_interview_agent(world_id, agent_id, ctx)
  }
}

fn execute_query_graph(entity_id: String, ctx: ToolContext) -> List(String) {
  case ctx.graph {
    None -> ["[QueryGraph] no graph available"]
    Some(graph) -> {
      let facts = store.get_facts_by_entity(graph, entity_id)
      case facts {
        [] -> ["[QueryGraph] no facts found for entity: " <> entity_id]
        _ -> list.map(facts, format_fact)
      }
    }
  }
}

fn execute_risk_snapshot(country_code: String, ctx: ToolContext) -> List(String) {
  case ctx.cii {
    None -> ["[RiskSnapshot] no CII server available"]
    Some(cii_srv) -> {
      let risk = cii_server.get_country(cii_srv, country_code)
      let trend_str = case risk.trend {
        cii.Rising -> "rising"
        cii.Stable -> "stable"
        cii.Falling -> "falling"
      }
      let score_str = float_to_str(risk.cii_score)
      [
        "[RiskSnapshot] " <> country_code <> " CII=" <> score_str <> " trend="
          <> trend_str,
      ]
    }
  }
}

fn execute_interview_agent(
  world_id: String,
  agent_id: String,
  ctx: ToolContext,
) -> List(String) {
  case ctx.registry {
    None -> ["[InterviewAgent] no registry available"]
    Some(reg) -> {
      let agents = registry.list_world_agents(reg, world_id)
      case list.contains(agents, agent_id) {
        True -> [
          "[InterviewAgent] agent " <> agent_id <> " in world " <> world_id
            <> " is available",
        ]
        False -> [
          "[InterviewAgent] agent " <> agent_id <> " not found in world "
            <> world_id,
        ]
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn format_fact(f: AtomicFact) -> String {
  let pred_str = relation_to_string(f.predicate)
  let conf_str = float_to_str(f.confidence)
  "[Fact] " <> f.subject <> " " <> pred_str <> " " <> f.object <> " (conf="
  <> conf_str <> ")"
}

fn relation_to_string(rel: entity.RelationKind) -> String {
  case rel {
    entity.Allied -> "allied"
    entity.Hostile -> "hostile"
    entity.TradePartner -> "trade_partner"
    entity.Sanctions -> "sanctions"
    entity.Owns -> "owns"
    entity.Controls -> "controls"
    entity.LocatedIn -> "located_in"
    entity.SuppliesTo -> "supplies_to"
    entity.MemberOf -> "member_of"
    entity.LeaderOf -> "leader_of"
    entity.Reports -> "reports"
  }
}

fn float_to_str(f: Float) -> String {
  int.to_string(erlang_trunc(f))
}

@external(erlang, "erlang", "trunc")
fn erlang_trunc(f: Float) -> Int
