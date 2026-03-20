/// Source credibility tracking with EMA-based accuracy updates.
pub type SourceCredibility {
  SourceCredibility(
    source_id: String,
    base_score: Float,
    accuracy: Float,
    freshness: Float,
    confirmation: Float,
    effective_score: Float,
  )
}

/// EMA alpha for accuracy updates.
const ema_alpha = 0.3

/// Create a new SourceCredibility with all factor dimensions at 1.0.
/// effective_score = base * (0.4*1.0 + 0.3*1.0 + 0.3*1.0) = base.
pub fn new(source_id: String, base_score: Float) -> SourceCredibility {
  SourceCredibility(
    source_id: source_id,
    base_score: base_score,
    accuracy: 1.0,
    freshness: 1.0,
    confirmation: 1.0,
    effective_score: base_score,
  )
}

/// Recompute effective_score = base * (0.4*accuracy + 0.3*freshness + 0.3*confirmation)
pub fn recompute(c: SourceCredibility) -> SourceCredibility {
  let weighted =
    0.4 *. c.accuracy +. 0.3 *. c.freshness +. 0.3 *. c.confirmation
  SourceCredibility(..c, effective_score: c.base_score *. weighted)
}

/// Record a confirmed prediction — boosts accuracy via EMA toward 1.0.
pub fn record_confirmation(c: SourceCredibility) -> SourceCredibility {
  let new_accuracy = ema(c.accuracy, 1.0)
  recompute(SourceCredibility(..c, accuracy: new_accuracy))
}

/// Record a missed prediction — degrades accuracy via EMA toward 0.0.
pub fn record_miss(c: SourceCredibility) -> SourceCredibility {
  let new_accuracy = ema(c.accuracy, 0.0)
  recompute(SourceCredibility(..c, accuracy: new_accuracy))
}

/// Exponential moving average: new = alpha * target + (1 - alpha) * current
fn ema(current: Float, target: Float) -> Float {
  ema_alpha *. target +. { 1.0 -. ema_alpha } *. current
}
