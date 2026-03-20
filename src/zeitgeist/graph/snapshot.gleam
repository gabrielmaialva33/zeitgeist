import gleam/erlang/process.{type Subject}
import zeitgeist/graph/store.{type GraphMsg}

/// Trigger decay on the graph store, removing facts older than max_age_hours.
pub fn run_decay(graph: Subject(GraphMsg), max_age_hours: Int) -> Nil {
  process.send(graph, store.RunDecay(max_age_hours: max_age_hours))
}
