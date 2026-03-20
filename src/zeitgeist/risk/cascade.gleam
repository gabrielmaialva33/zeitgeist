import gleam/dict.{type Dict}
import gleam/list

pub type InfraKind {
  SubmarineCableNode
  PipelineNode
  PortNode
  ChokePoint
  PowerGridNode
  TradeRoute
}

pub type Dependency {
  Dependency(target: String, weight: Float, lag_hours: Float)
}

pub type InfraNode {
  InfraNode(
    id: String,
    kind: InfraKind,
    capacity: Float,
    redundancy: Float,
    dependents: List(Dependency),
  )
}

pub type CascadeGraph =
  Dict(String, InfraNode)

pub type CascadeImpact {
  CascadeImpact(node_id: String, impact: Float, depth: Int, lag_hours: Float)
}

pub fn new_graph() -> CascadeGraph {
  dict.new()
}

pub fn add_node(graph: CascadeGraph, node: InfraNode) -> CascadeGraph {
  dict.insert(graph, node.id, node)
}

pub fn propagate(
  graph: CascadeGraph,
  trigger_id: String,
  disruption_level: Float,
  max_depth: Int,
) -> List(CascadeImpact) {
  // BFS: queue items are #(node_id, impact, depth, lag_hours)
  // visited tracks nodes already enqueued to avoid cycles
  let initial_queue = [#(trigger_id, disruption_level, 0, 0.0)]
  let visited = [trigger_id]
  do_bfs(graph, initial_queue, visited, max_depth, [])
}

fn do_bfs(
  graph: CascadeGraph,
  queue: List(#(String, Float, Int, Float)),
  visited: List(String),
  max_depth: Int,
  acc: List(CascadeImpact),
) -> List(CascadeImpact) {
  case queue {
    [] -> list.reverse(acc)
    [#(node_id, impact, depth, lag), ..rest] -> {
      let new_acc = [
        CascadeImpact(
          node_id: node_id,
          impact: impact,
          depth: depth,
          lag_hours: lag,
        ),
        ..acc
      ]
      // Expand dependents only if under max_depth
      case depth < max_depth {
        False -> do_bfs(graph, rest, visited, max_depth, new_acc)
        True -> {
          case dict.get(graph, node_id) {
            Error(_) -> do_bfs(graph, rest, visited, max_depth, new_acc)
            Ok(node) -> {
              let #(new_items, new_visited) =
                list.fold(node.dependents, #([], visited), fn(state, dep) {
                  let #(items, vis) = state
                  case list.contains(vis, dep.target) {
                    True -> state
                    False -> {
                      let child_impact = case dict.get(graph, dep.target) {
                        Error(_) -> dep.weight *. impact
                        Ok(target_node) ->
                          dep.weight
                          *. impact
                          *. { 1.0 -. target_node.redundancy }
                      }
                      let child_lag = lag +. dep.lag_hours
                      #(
                        [
                          #(dep.target, child_impact, depth + 1, child_lag),
                          ..items
                        ],
                        [dep.target, ..vis],
                      )
                    }
                  }
                })
              // Append new items to end of queue (BFS order)
              let next_queue = list.append(rest, list.reverse(new_items))
              do_bfs(graph, next_queue, new_visited, max_depth, new_acc)
            }
          }
        }
      }
    }
  }
}

pub fn impact_at_depth(
  impacts: List(CascadeImpact),
  depth: Int,
) -> List(CascadeImpact) {
  list.filter(impacts, fn(i) { i.depth == depth })
}
