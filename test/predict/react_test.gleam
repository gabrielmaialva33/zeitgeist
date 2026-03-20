import gleam/erlang/process
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should
import zeitgeist/core/bus
import zeitgeist/core/entity
import zeitgeist/graph/fact.{AtomicFact}
import zeitgeist/graph/store
import zeitgeist/predict/react
import zeitgeist/risk/cii_server

pub fn main() {
  gleeunit.main()
}

pub fn query_graph_no_context_test() {
  let ctx = react.empty_context()
  let obs = react.execute_tool(react.QueryGraphTool("iran"), ctx)
  obs |> should.equal(["[QueryGraph] no graph available"])
}

pub fn query_graph_returns_facts_test() {
  let assert Ok(graph) = store.start("react_fact_" <> unique())

  let fact =
    AtomicFact(
      id: "f1",
      subject: "iran",
      predicate: entity.Hostile,
      object: "usa",
      observed_at: 1000,
      valid_from: 1000,
      valid_until: None,
      confidence: 0.9,
      source_credibility: 0.95,
      frequency: 1,
    )
  store.upsert_fact(graph, fact)

  let ctx = react.ToolContext(graph: Some(graph), cii: None, registry: None)
  let obs = react.execute_tool(react.QueryGraphTool("iran"), ctx)

  list.length(obs) |> should.equal(1)
  let assert [line] = obs
  should.be_true(string.contains(line, "iran"))
  should.be_true(string.contains(line, "hostile"))
  should.be_true(string.contains(line, "usa"))

  store.stop(graph)
}

pub fn query_graph_no_facts_test() {
  let assert Ok(graph) = store.start("react_empty_" <> unique())
  let ctx = react.ToolContext(graph: Some(graph), cii: None, registry: None)
  let obs = react.execute_tool(react.QueryGraphTool("unknown_entity"), ctx)

  list.length(obs) |> should.equal(1)
  let assert [line] = obs
  should.be_true(string.contains(line, "no facts found"))

  store.stop(graph)
}

pub fn risk_snapshot_no_context_test() {
  let ctx = react.empty_context()
  let obs = react.execute_tool(react.RiskSnapshotTool("IR"), ctx)
  obs |> should.equal(["[RiskSnapshot] no CII server available"])
}

pub fn risk_snapshot_returns_cii_test() {
  let assert Ok(b) = bus.start()
  let assert Ok(cii_srv) = cii_server.start(b)

  cii_server.update_country(cii_srv, "IR", 75.0)
  process.sleep(50)

  let ctx = react.ToolContext(graph: None, cii: Some(cii_srv), registry: None)
  let obs = react.execute_tool(react.RiskSnapshotTool("IR"), ctx)

  list.length(obs) |> should.equal(1)
  let assert [line] = obs
  should.be_true(string.contains(line, "[RiskSnapshot]"))
  should.be_true(string.contains(line, "IR"))
  should.be_true(string.contains(line, "CII="))
  should.be_true(string.contains(line, "trend="))

  cii_server.stop(cii_srv)
}

pub fn react_step_constructors_test() {
  let thought = react.Thought("What do we know about iran?")
  let action = react.Action(react.QueryGraphTool("iran"))
  let obs = react.Observation(["[Fact] iran hostile usa"])
  let _ = thought
  let _ = action
  let _ = obs
  should.be_true(True)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

@external(erlang, "erlang", "unique_integer")
fn unique_int() -> Int

fn unique() -> String {
  int_to_string(unique_int())
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string(i: Int) -> String
