import gleam/bit_array
import gleam/crypto
import gleam/list
import gleam/string
import zeitgeist/core/event.{type Event}

pub type DedupResult {
  New
  Similar
  Duplicate
}

/// Normalize text: lowercase, trim.
fn normalize(text: String) -> String {
  text
  |> string.lowercase
  |> string.trim
}

/// Extract raw (un-normalized) text content from an event for fingerprinting.
/// Raw content preserves case/spacing differences, so that case variants yield
/// different fingerprints and fall through to the Similar check.
fn content_text(evt: Event) -> String {
  case evt.kind {
    event.NewsArticle(title: t, summary: s, ..) ->
      string.concat([string.trim(t), "|", string.trim(s)])
    event.MarketTick(symbol: sym, ..) -> string.concat(["market|", sym])
    event.MilitaryTrack(callsign: cs, ..) ->
      string.concat(["military|", string.trim(cs)])
    event.InfraStatus(infra_type: it, status: st) ->
      string.concat(["infra|", string.inspect(it), "|", string.inspect(st)])
    event.SeismicReading(magnitude: mag, depth_km: depth) ->
      string.concat([
        "seismic|",
        string.inspect(mag),
        "|",
        string.inspect(depth),
      ])
    event.WeatherAlert(phenomenon: ph, ..) ->
      string.concat(["weather|", string.trim(ph)])
    event.RiskAlert(details: d, ..) ->
      string.concat(["risk|", string.trim(d)])
    event.PredictionEvent(scenario_id: sid, ..) ->
      string.concat(["prediction|", sid])
    event.CorrelationHit(pattern: p, ..) ->
      string.concat(["correlation|", string.trim(p)])
  }
}

/// Compute SHA256 fingerprint of event content (raw, not normalized).
pub fn fingerprint(evt: Event) -> String {
  let text = content_text(evt)
  let bits = bit_array.from_string(text)
  let hash = crypto.hash(crypto.Sha256, bits)
  bit_array.base16_encode(hash)
}

/// Extract normalized title (for similarity check) — only applicable to news.
fn normalized_title(evt: Event) -> String {
  case evt.kind {
    event.NewsArticle(title: t, ..) -> normalize(t)
    _ -> ""
  }
}

/// Two hours in milliseconds.
const two_hours_ms = 7_200_000

/// Check incoming event against existing list.
/// Returns Duplicate if fingerprint matches exactly, Similar if same normalized
/// title within 2h window, New otherwise.
pub fn check(existing: List(Event), incoming: Event) -> DedupResult {
  let fp = fingerprint(incoming)
  let incoming_title = normalized_title(incoming)

  case
    list.find(existing, fn(e) { fingerprint(e) == fp })
  {
    Ok(_) -> Duplicate
    Error(_) -> {
      // Check similar: same normalized title within 2h window
      case
        incoming_title != ""
        && list.any(existing, fn(e) {
          normalized_title(e) == incoming_title
          && abs_diff(e.timestamp, incoming.timestamp) <= two_hours_ms
        })
      {
        True -> Similar
        False -> New
      }
    }
  }
}

fn abs_diff(a: Int, b: Int) -> Int {
  case a >= b {
    True -> a - b
    False -> b - a
  }
}
