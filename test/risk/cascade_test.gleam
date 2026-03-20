import gleam/list
import gleeunit
import gleeunit/should
import zeitgeist/risk/cascade

pub fn main() {
  gleeunit.main()
}

pub fn single_node_test() {
  let graph =
    cascade.new_graph()
    |> cascade.add_node(
      cascade.InfraNode(
        id: "suez",
        kind: cascade.ChokePoint,
        capacity: 1.0,
        redundancy: 0.1,
        dependents: [],
      ),
    )
  let impacts = cascade.propagate(graph, "suez", 0.9, 3)
  list.length(impacts) |> should.equal(1)
  let assert [impact] = impacts
  impact.node_id |> should.equal("suez")
  impact.impact |> should.equal(0.9)
  impact.depth |> should.equal(0)
}

pub fn propagation_to_dependents_test() {
  // suez -> rotterdam (weight 0.8, redundancy 0.2)
  // child impact = 0.8 * 0.9 * (1 - 0.2) = 0.576
  let graph =
    cascade.new_graph()
    |> cascade.add_node(
      cascade.InfraNode(
        id: "suez",
        kind: cascade.ChokePoint,
        capacity: 1.0,
        redundancy: 0.0,
        dependents: [
          cascade.Dependency(target: "rotterdam", weight: 0.8, lag_hours: 6.0),
        ],
      ),
    )
    |> cascade.add_node(
      cascade.InfraNode(
        id: "rotterdam",
        kind: cascade.PortNode,
        capacity: 0.9,
        redundancy: 0.2,
        dependents: [],
      ),
    )
  let impacts = cascade.propagate(graph, "suez", 0.9, 3)
  list.length(impacts) |> should.equal(2)
  let child = find_impact(impacts, "rotterdam")
  let assert True = child.impact >. 0.575
  let assert True = child.impact <. 0.578
  child.depth |> should.equal(1)
  child.lag_hours |> should.equal(6.0)
}

pub fn max_depth_limits_propagation_test() {
  // a -> b -> c -> d, max_depth = 1 should only yield a and b
  let graph =
    cascade.new_graph()
    |> cascade.add_node(
      cascade.InfraNode(
        id: "a",
        kind: cascade.PowerGridNode,
        capacity: 1.0,
        redundancy: 0.0,
        dependents: [
          cascade.Dependency(target: "b", weight: 1.0, lag_hours: 0.0),
        ],
      ),
    )
    |> cascade.add_node(
      cascade.InfraNode(
        id: "b",
        kind: cascade.PowerGridNode,
        capacity: 1.0,
        redundancy: 0.0,
        dependents: [
          cascade.Dependency(target: "c", weight: 1.0, lag_hours: 0.0),
        ],
      ),
    )
    |> cascade.add_node(
      cascade.InfraNode(
        id: "c",
        kind: cascade.PowerGridNode,
        capacity: 1.0,
        redundancy: 0.0,
        dependents: [
          cascade.Dependency(target: "d", weight: 1.0, lag_hours: 0.0),
        ],
      ),
    )
    |> cascade.add_node(
      cascade.InfraNode(
        id: "d",
        kind: cascade.PowerGridNode,
        capacity: 1.0,
        redundancy: 0.0,
        dependents: [],
      ),
    )
  let impacts = cascade.propagate(graph, "a", 1.0, 1)
  list.length(impacts) |> should.equal(2)
}

pub fn redundancy_reduces_impact_test() {
  // high redundancy (0.9) should greatly reduce child impact
  let graph =
    cascade.new_graph()
    |> cascade.add_node(
      cascade.InfraNode(
        id: "src",
        kind: cascade.PipelineNode,
        capacity: 1.0,
        redundancy: 0.0,
        dependents: [
          cascade.Dependency(target: "dst", weight: 1.0, lag_hours: 0.0),
        ],
      ),
    )
    |> cascade.add_node(
      cascade.InfraNode(
        id: "dst",
        kind: cascade.PipelineNode,
        capacity: 1.0,
        redundancy: 0.9,
        dependents: [],
      ),
    )
  let impacts = cascade.propagate(graph, "src", 1.0, 3)
  let child = find_impact(impacts, "dst")
  // impact = 1.0 * 1.0 * (1 - 0.9) = 0.1
  let assert True = child.impact >. 0.09
  let assert True = child.impact <. 0.11
}

pub fn no_cycle_test() {
  // a -> b -> a (cycle): each should be visited exactly once
  let graph =
    cascade.new_graph()
    |> cascade.add_node(
      cascade.InfraNode(
        id: "a",
        kind: cascade.TradeRoute,
        capacity: 1.0,
        redundancy: 0.0,
        dependents: [
          cascade.Dependency(target: "b", weight: 0.5, lag_hours: 0.0),
        ],
      ),
    )
    |> cascade.add_node(
      cascade.InfraNode(
        id: "b",
        kind: cascade.TradeRoute,
        capacity: 1.0,
        redundancy: 0.0,
        dependents: [
          cascade.Dependency(target: "a", weight: 0.5, lag_hours: 0.0),
        ],
      ),
    )
  let impacts = cascade.propagate(graph, "a", 1.0, 10)
  list.length(impacts) |> should.equal(2)
}

fn find_impact(
  impacts: List(cascade.CascadeImpact),
  id: String,
) -> cascade.CascadeImpact {
  let assert [i] = list.filter(impacts, fn(x) { x.node_id == id })
  i
}
