import gleam/option.{type Option, None, Some}
import gleam/string
import zeitgeist/core/event.{type Event}
import zeitgeist/predict/scenario.{
  type Scenario, type ValidationOutcome, ConfirmedOutcome, ConflictEscalation,
  Down, MarketMove, PartialMatch, Up,
}

pub fn check_prediction(
  scenario: Scenario,
  event: Event,
) -> Option(ValidationOutcome) {
  case scenario.prediction {
    ConflictEscalation(region: region, ..) -> {
      case event.kind {
        event.NewsArticle(title: title, ..) -> {
          case string.contains(title, region) {
            True -> Some(ConfirmedOutcome(accuracy: 1.0, lag_hours: 0.0))
            False -> None
          }
        }
        _ -> None
      }
    }

    MarketMove(symbol: symbol, direction: direction, ..) -> {
      case event.kind {
        event.MarketTick(symbol: tick_symbol, change_pct: change_pct, ..) -> {
          case tick_symbol == symbol {
            True -> {
              let direction_matches = case direction {
                Up -> change_pct >. 0.0
                Down -> change_pct <. 0.0
              }
              case direction_matches {
                True -> Some(ConfirmedOutcome(accuracy: 1.0, lag_hours: 0.0))
                False ->
                  Some(PartialMatch(
                    accuracy: 0.5,
                    deviation: "direction mismatch",
                  ))
              }
            }
            False -> None
          }
        }
        _ -> None
      }
    }

    _ -> None
  }
}
