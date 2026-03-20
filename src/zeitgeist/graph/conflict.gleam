import gleam/float
import gleam/int
import zeitgeist/graph/fact.{type AtomicFact}

pub type Resolution {
  Supersede(close_old: AtomicFact, accept: AtomicFact)
  Reject(keep: AtomicFact, discard: AtomicFact)
}

pub fn resolve(existing: AtomicFact, incoming: AtomicFact, now_ms: Int) -> Resolution {
  let existing_score = weighted_score(existing, now_ms)
  let incoming_score = weighted_score(incoming, now_ms)
  case incoming_score >. existing_score {
    True -> Supersede(close_old: existing, accept: incoming)
    False -> Reject(keep: existing, discard: incoming)
  }
}

fn weighted_score(f: AtomicFact, now_ms: Int) -> Float {
  let age_hours = int.to_float(now_ms - f.observed_at) /. 3_600_000.0
  let recency = recency_boost(age_hours)
  let freq_norm = frequency_normalize(f.frequency)
  f.confidence *. f.source_credibility *. recency *. freq_norm
}

fn recency_boost(age_hours: Float) -> Float {
  let lambda = 0.6931471805599453 /. 168.0
  exp(float.negate(lambda *. age_hours))
}

fn frequency_normalize(frequency: Int) -> Float {
  let f = int.to_float(frequency)
  log2(f +. 1.0) /. log2(51.0)
}

fn log2(x: Float) -> Float {
  log(x) /. 0.6931471805599453
}

@external(erlang, "math", "exp")
fn exp(x: Float) -> Float

@external(erlang, "math", "log")
fn log(x: Float) -> Float
