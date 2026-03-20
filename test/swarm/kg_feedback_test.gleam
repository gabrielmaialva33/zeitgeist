import gleam/string
import gleeunit
import gleeunit/should
import zeitgeist/agent/action.{
  DiplomaticMessage, DoNothing, FormAlliance, IssueSanction, MilitaryAction,
  Mobilize, ObserveAndWait,
}
import zeitgeist/core/entity
import zeitgeist/graph/store
import zeitgeist/swarm/kg_feedback

pub fn main() {
  gleeunit.main()
}

const ts = 1_700_000_000_000

// ---------------------------------------------------------------------------
// action_to_fact conversions
// ---------------------------------------------------------------------------

pub fn diplomatic_message_maps_to_allied_test() {
  let action = DiplomaticMessage(to: "russia", content: "Peace talks", public: True)
  let result = kg_feedback.action_to_fact("usa", "w1", action, ts)
  let assert Ok(fact) = result
  should.equal(fact.predicate, entity.Allied)
  should.equal(fact.subject, "usa")
  should.equal(fact.object, "russia")
  should.equal(fact.observed_at, ts)
}

pub fn issue_sanction_maps_to_sanctions_test() {
  let action = IssueSanction(target_country: "iran", severity: 0.8)
  let assert Ok(fact) = kg_feedback.action_to_fact("us", "w1", action, ts)
  should.equal(fact.predicate, entity.Sanctions)
  should.equal(fact.subject, "us")
  should.equal(fact.object, "iran")
}

pub fn military_action_maps_to_hostile_test() {
  let action = MilitaryAction(action: Mobilize, target: "border")
  let assert Ok(fact) = kg_feedback.action_to_fact("nato", "w1", action, ts)
  should.equal(fact.predicate, entity.Hostile)
  should.equal(fact.subject, "nato")
  should.equal(fact.object, "border")
}

pub fn form_alliance_maps_to_allied_test() {
  let action = FormAlliance(target_country: "uk")
  let assert Ok(fact) = kg_feedback.action_to_fact("usa", "w1", action, ts)
  should.equal(fact.predicate, entity.Allied)
  should.equal(fact.object, "uk")
}

pub fn do_nothing_returns_error_test() {
  let result = kg_feedback.action_to_fact("agent1", "w1", DoNothing, ts)
  should.be_error(result)
}

pub fn observe_and_wait_returns_error_test() {
  let result = kg_feedback.action_to_fact("agent1", "w1", ObserveAndWait, ts)
  should.be_error(result)
}

pub fn fact_id_includes_world_agent_and_relation_test() {
  let action = DiplomaticMessage(to: "uk", content: "Hello", public: False)
  let assert Ok(fact) = kg_feedback.action_to_fact("usa", "world42", action, ts)
  should.be_true(
    string.contains(fact.id, "world42")
    && string.contains(fact.id, "usa")
    && string.contains(fact.id, "allied"),
  )
}

// ---------------------------------------------------------------------------
// record_to_graph integration
// ---------------------------------------------------------------------------

pub fn record_to_graph_inserts_fact_test() {
  let assert Ok(graph) = store.start("kg_feedback_test")
  let action = FormAlliance(target_country: "france")
  kg_feedback.record_to_graph(graph, "usa", "world1", action, ts)
  let facts = store.get_facts_by_entity(graph, "usa")
  should.be_true(facts != [])
  let assert [fact] = facts
  should.equal(fact.predicate, entity.Allied)
  should.equal(fact.object, "france")
  store.stop(graph)
}

pub fn record_to_graph_skips_do_nothing_test() {
  let assert Ok(graph) = store.start("kg_feedback_skip_test")
  kg_feedback.record_to_graph(graph, "agent1", "world1", DoNothing, ts)
  let count = store.fact_count(graph)
  should.equal(count, 0)
  store.stop(graph)
}
