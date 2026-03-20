// Sim→KG feedback: converts agent actions into AtomicFacts and records them
// in the knowledge graph.

import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/option.{None}
import zeitgeist/agent/action.{
  type AgentActionType, DiplomaticMessage, DoNothing, FormAlliance,
  IssueSanction, MilitaryAction, ObserveAndWait,
}
import zeitgeist/core/entity
import zeitgeist/graph/fact.{type AtomicFact, AtomicFact}
import zeitgeist/graph/store.{type GraphMsg}

// ---------------------------------------------------------------------------
// Pure conversion
// ---------------------------------------------------------------------------

/// Convert an agent action into an AtomicFact.
/// Returns Error(Nil) for actions that don't map to a relation (DoNothing, ObserveAndWait).
pub fn action_to_fact(
  agent_id: String,
  world_id: String,
  action: AgentActionType,
  timestamp: Int,
) -> Result(AtomicFact, Nil) {
  case action {
    DiplomaticMessage(to: target, content: _, public: _) ->
      Ok(make_fact(agent_id, entity.Allied, target, world_id, timestamp))

    IssueSanction(target_country: target, severity: _) ->
      Ok(make_fact(agent_id, entity.Sanctions, target, world_id, timestamp))

    MilitaryAction(action: _, target: target) ->
      Ok(make_fact(agent_id, entity.Hostile, target, world_id, timestamp))

    FormAlliance(target_country: target) ->
      Ok(make_fact(agent_id, entity.Allied, target, world_id, timestamp))

    DoNothing -> Error(Nil)
    ObserveAndWait -> Error(Nil)
    _ -> Error(Nil)
  }
}

/// Record an agent action as a fact in the graph. No-op for actions without
/// a relation mapping.
pub fn record_to_graph(
  graph_subject: Subject(GraphMsg),
  agent_id: String,
  world_id: String,
  action: AgentActionType,
  timestamp: Int,
) -> Nil {
  case action_to_fact(agent_id, world_id, action, timestamp) {
    Ok(f) -> store.upsert_fact(graph_subject, f)
    Error(Nil) -> Nil
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn make_fact(
  subject_id: String,
  predicate: entity.RelationKind,
  object_id: String,
  world_id: String,
  timestamp: Int,
) -> AtomicFact {
  let id =
    "sim_"
    <> world_id
    <> "_"
    <> subject_id
    <> "_"
    <> relation_to_string(predicate)
    <> "_"
    <> object_id
    <> "_"
    <> int.to_string(timestamp)
  AtomicFact(
    id: id,
    subject: subject_id,
    predicate: predicate,
    object: object_id,
    observed_at: timestamp,
    valid_from: timestamp,
    valid_until: None,
    confidence: 0.7,
    source_credibility: 0.6,
    frequency: 1,
  )
}

fn relation_to_string(rel: entity.RelationKind) -> String {
  case rel {
    entity.Allied -> "allied"
    entity.Hostile -> "hostile"
    entity.Sanctions -> "sanctions"
    entity.TradePartner -> "trade_partner"
    entity.Owns -> "owns"
    entity.Controls -> "controls"
    entity.LocatedIn -> "located_in"
    entity.SuppliesTo -> "supplies_to"
    entity.MemberOf -> "member_of"
    entity.LeaderOf -> "leader_of"
    entity.Reports -> "reports"
  }
}
