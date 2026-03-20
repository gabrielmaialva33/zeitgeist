import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import zeitgeist/core/event.{type Event}
import zeitgeist/predict/scenario.{
  type Scenario, type ScenarioStatus, Active, ConfirmedOutcome, PartialMatch,
  Refuted, ScenarioConfirmed, ScenarioInvalidated,
}
import zeitgeist/predict/validator

// ---------------------------------------------------------------------------
// Message type
// ---------------------------------------------------------------------------

pub type FeedbackMsg {
  AddPrediction(scenario: Scenario)
  CheckEvent(event: Event)
  ListActive(reply_to: Subject(List(Scenario)))
  GetStats(reply_to: Subject(FeedbackStats))
  FeedbackStop
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

pub type FeedbackStats {
  FeedbackStats(
    active: Int,
    checked: Int,
    confirmed: Int,
    refuted: Int,
    expired: Int,
  )
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

type FeedbackState {
  FeedbackState(
    scenarios: List(Scenario),
    checked: Int,
    confirmed: Int,
    refuted: Int,
    expired: Int,
  )
}

fn init_state() -> FeedbackState {
  FeedbackState(
    scenarios: [],
    checked: 0,
    confirmed: 0,
    refuted: 0,
    expired: 0,
  )
}

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

pub fn start() -> Result(Subject(FeedbackMsg), actor.StartError) {
  let r =
    actor.new(init_state())
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn stop(fb: Subject(FeedbackMsg)) -> Nil {
  process.send(fb, FeedbackStop)
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn add_prediction(fb: Subject(FeedbackMsg), s: Scenario) -> Nil {
  process.send(fb, AddPrediction(s))
}

pub fn check_event(fb: Subject(FeedbackMsg), event: Event) -> Nil {
  process.send(fb, CheckEvent(event))
}

pub fn list_active(fb: Subject(FeedbackMsg)) -> List(Scenario) {
  process.call(fb, waiting: 5000, sending: fn(reply_to) {
    ListActive(reply_to)
  })
}

pub fn get_stats(fb: Subject(FeedbackMsg)) -> FeedbackStats {
  process.call(fb, waiting: 5000, sending: fn(reply_to) { GetStats(reply_to) })
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

fn handle_message(
  state: FeedbackState,
  msg: FeedbackMsg,
) -> actor.Next(FeedbackState, FeedbackMsg) {
  case msg {
    AddPrediction(s) -> {
      actor.continue(FeedbackState(..state, scenarios: [s, ..state.scenarios]))
    }

    CheckEvent(event) -> {
      actor.continue(validate_all(state, event))
    }

    ListActive(reply_to) -> {
      let active =
        list.filter(state.scenarios, fn(s) { is_active_status(s.status) })
      process.send(reply_to, active)
      actor.continue(state)
    }

    GetStats(reply_to) -> {
      let active_count =
        list.length(list.filter(state.scenarios, fn(s) {
          is_active_status(s.status)
        }))
      let stats =
        FeedbackStats(
          active: active_count,
          checked: state.checked,
          confirmed: state.confirmed,
          refuted: state.refuted,
          expired: state.expired,
        )
      process.send(reply_to, stats)
      actor.continue(state)
    }

    FeedbackStop -> actor.stop()
  }
}

// ---------------------------------------------------------------------------
// Validation logic
// ---------------------------------------------------------------------------

fn validate_all(state: FeedbackState, event: Event) -> FeedbackState {
  list.fold(state.scenarios, state, fn(st, s) {
    case is_active_status(s.status) {
      False -> st
      True -> {
        case validator.check_prediction(s, event) {
          None -> st
          Some(outcome) -> {
            let new_status = outcome_to_status(outcome)
            let updated = scenario.Scenario(..s, status: new_status)
            let new_scenarios =
              list.map(st.scenarios, fn(existing) {
                case existing.id == s.id {
                  True -> updated
                  False -> existing
                }
              })
            let new_confirmed = case new_status {
              ScenarioConfirmed(_, _) -> st.confirmed + 1
              _ -> st.confirmed
            }
            let new_refuted = case new_status {
              ScenarioInvalidated(_) -> st.refuted + 1
              _ -> st.refuted
            }
            FeedbackState(
              ..st,
              scenarios: new_scenarios,
              checked: st.checked + 1,
              confirmed: new_confirmed,
              refuted: new_refuted,
            )
          }
        }
      }
    }
  })
}

fn outcome_to_status(outcome: scenario.ValidationOutcome) -> ScenarioStatus {
  case outcome {
    ConfirmedOutcome(accuracy, lag_hours) ->
      ScenarioConfirmed(accuracy: accuracy, lag_hours: lag_hours)
    PartialMatch(_, _) -> Active
    Refuted(reason) -> ScenarioInvalidated(reason: reason)
  }
}

fn is_active_status(status: ScenarioStatus) -> Bool {
  case status {
    Active -> True
    _ -> False
  }
}
