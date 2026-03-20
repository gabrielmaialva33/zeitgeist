import gleam/json.{type Json}
import zeitgeist/risk/cii.{type CountryRisk}

pub fn health(status: String) -> Json {
  json.object([
    #("status", json.string(status)),
    #("service", json.string("zeitgeist")),
    #("version", json.string("0.1.0")),
  ])
}

pub fn country_risk(risk: CountryRisk) -> Json {
  json.object([
    #("country_code", json.string(risk.country_code)),
    #("cii_score", json.float(risk.cii_score)),
    #("trend", json.string(trend_to_string(risk.trend))),
  ])
}

fn trend_to_string(trend: cii.Trend) -> String {
  case trend {
    cii.Rising -> "rising"
    cii.Stable -> "stable"
    cii.Falling -> "falling"
  }
}

pub fn error_json(message: String) -> Json {
  json.object([#("error", json.string(message))])
}
