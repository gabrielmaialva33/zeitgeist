pub type Scenario {
  Scenario(
    id: String,
    world_id: String,
    prediction: PredictionClaim,
    confidence: Float,
    horizon_hours: Int,
    created_at: Int,
    status: ScenarioStatus,
  )
}

pub type PredictionClaim {
  ConflictEscalation(region: String, from_level: Int, to_level: Int)
  MarketMove(symbol: String, direction: Direction, magnitude_pct: Float)
  InfraDisruption(infra_id: String, severity: Float)
  NarrativeShift(topic: String, from_sentiment: Float, to_sentiment: Float)
  PredictedDiplomaticAction(
    actor_name: String,
    action_type: String,
    target: String,
  )
}

pub type Direction {
  Up
  Down
}

pub type ScenarioStatus {
  Active
  ScenarioConfirmed(accuracy: Float, lag_hours: Float)
  ScenarioInvalidated(reason: String)
  Expired
}

pub type ValidationOutcome {
  ConfirmedOutcome(accuracy: Float, lag_hours: Float)
  PartialMatch(accuracy: Float, deviation: String)
  Refuted(reason: String)
}

pub fn new(
  id: String,
  world_id: String,
  prediction: PredictionClaim,
  confidence: Float,
  horizon_hours: Int,
) -> Scenario {
  Scenario(
    id: id,
    world_id: world_id,
    prediction: prediction,
    confidence: confidence,
    horizon_hours: horizon_hours,
    created_at: 0,
    status: Active,
  )
}

pub fn check_expiry(scenario: Scenario, now_ms: Int) -> Scenario {
  case scenario.status {
    Active -> {
      let horizon_ms = scenario.horizon_hours * 3_600_000
      case now_ms - scenario.created_at >= horizon_ms {
        True -> Scenario(..scenario, status: Expired)
        False -> scenario
      }
    }
    _ -> scenario
  }
}
