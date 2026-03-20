import gleam/dict
import gleam/list
import zeitgeist/graph/fact.{type AtomicFact}

pub type EmergingCluster {
  EmergingCluster(entity_id: String, new_relations: Int, avg_confidence: Float)
}

/// Detect entities with unusually high recent activity.
///
/// - facts: all known facts
/// - now_ms: current time in milliseconds
/// - window_ms: how far back to look
/// - min_new_relations: minimum fact count to qualify
pub fn detect(
  facts: List(AtomicFact),
  now_ms: Int,
  window_ms: Int,
  min_new_relations: Int,
) -> List(EmergingCluster) {
  let cutoff = now_ms - window_ms

  // Filter to facts within the window
  let recent = list.filter(facts, fn(f) { f.observed_at >= cutoff })

  // Group by subject: accumulate (count, sum_confidence)
  let grouped =
    list.fold(recent, dict.new(), fn(acc, f) {
      let current =
        dict.get(acc, f.subject)
        |> result_unwrap(#(0, 0.0))
      let #(cnt, sum) = current
      dict.insert(acc, f.subject, #(cnt + 1, sum +. f.confidence))
    })

  // Convert to EmergingCluster, filter by threshold
  dict.fold(grouped, [], fn(acc, entity_id, stats) {
    let #(cnt, sum) = stats
    case cnt >= min_new_relations {
      False -> acc
      True -> {
        let avg = sum /. int_to_float(cnt)
        [
          EmergingCluster(
            entity_id: entity_id,
            new_relations: cnt,
            avg_confidence: avg,
          ),
          ..acc
        ]
      }
    }
  })
}

fn result_unwrap(r: Result(a, b), default: a) -> a {
  case r {
    Ok(v) -> v
    Error(_) -> default
  }
}

@external(erlang, "erlang", "float")
fn int_to_float(n: Int) -> Float
