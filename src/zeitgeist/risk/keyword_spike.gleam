// Keyword spike detection — pure functions, no actors
import gleam/dict.{type Dict}
import gleam/float
import gleam/list
import gleam/set
import gleam/string

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

pub type Spike {
  Spike(
    keyword: String,
    recent_count: Int,
    baseline_rate: Float,
    multiplier: Float,
    source_count: Int,
    confidence: Float,
  )
}

pub type KeywordEntry {
  KeywordEntry(
    // List of #(timestamp, source_id)
    mentions: List(#(Int, String)),
    last_spike_at: Int,
  )
}

pub type KeywordTracker =
  Dict(String, KeywordEntry)

// ---------------------------------------------------------------------------
// Stop words
// ---------------------------------------------------------------------------

const stop_words = [
  "the", "and", "for", "that", "with", "this", "from", "has", "have", "was",
  "were", "been", "are", "but", "not",
]

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

// 2 hours in ms
const two_hours_ms = 7_200_000

// 7 days in ms
const seven_days_ms = 604_800_000

// 30 minutes in ms
const cooldown_ms = 1_800_000

// Spike trigger thresholds
const min_recent_count = 5

const min_multiplier = 3.0

const min_source_count = 2

// Confidence params
const base_confidence = 0.6

const confidence_per_mult = 0.1

const max_confidence = 0.95

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn new_tracker() -> KeywordTracker {
  dict.new()
}

/// Extract keywords: lowercase, split on punctuation, filter >=3 chars, remove stop words, dedup.
pub fn extract_keywords(text: String) -> List(String) {
  text
  |> string.lowercase
  |> normalize_punctuation
  |> string.split(" ")
  |> list.filter(fn(w) { string.length(w) >= 3 })
  |> list.filter(fn(w) { !list.contains(stop_words, w) })
  |> dedup_list
}

/// Ingest keywords from a source at a given timestamp.
/// Returns updated tracker and list of newly detected spikes.
pub fn ingest(
  tracker: KeywordTracker,
  keywords: List(String),
  source_id: String,
  timestamp: Int,
) -> #(KeywordTracker, List(Spike)) {
  let #(new_tracker, spikes) =
    list.fold(keywords, #(tracker, []), fn(acc, keyword) {
      let #(t, s) = acc
      let entry = case dict.get(t, keyword) {
        Ok(e) -> e
        Error(_) -> KeywordEntry(mentions: [], last_spike_at: 0)
      }
      let new_mentions = [#(timestamp, source_id), ..entry.mentions]
      let new_entry = KeywordEntry(..entry, mentions: new_mentions)
      let #(final_entry, maybe_spike) =
        check_spike(new_entry, keyword, timestamp)
      let updated_tracker = dict.insert(t, keyword, final_entry)
      let updated_spikes = case maybe_spike {
        Ok(spike) -> [spike, ..s]
        Error(_) -> s
      }
      #(updated_tracker, updated_spikes)
    })
  #(new_tracker, spikes)
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

/// Replace common punctuation with spaces so words get split correctly.
fn normalize_punctuation(text: String) -> String {
  text
  |> string.replace(",", " ")
  |> string.replace(".", " ")
  |> string.replace("!", " ")
  |> string.replace("?", " ")
  |> string.replace(";", " ")
  |> string.replace(":", " ")
  |> string.replace("\"", " ")
  |> string.replace("'", " ")
  |> string.replace("(", " ")
  |> string.replace(")", " ")
  |> string.replace("-", " ")
  |> string.replace("/", " ")
}

/// Deduplicate a list while preserving first-occurrence order.
fn dedup_list(lst: List(String)) -> List(String) {
  let #(result, _seen) =
    list.fold(lst, #([], set.new()), fn(acc, item) {
      let #(out, seen) = acc
      case set.contains(seen, item) {
        True -> #(out, seen)
        False -> #([item, ..out], set.insert(seen, item))
      }
    })
  list.reverse(result)
}

/// Check if the keyword should trigger a spike.
fn check_spike(
  entry: KeywordEntry,
  keyword: String,
  now: Int,
) -> #(KeywordEntry, Result(Spike, Nil)) {
  // Cooldown: suppress if spiked in last 30 minutes
  let in_cooldown = now - entry.last_spike_at < cooldown_ms

  // Rolling 2h window
  let cutoff_2h = now - two_hours_ms
  let recent =
    list.filter(entry.mentions, fn(m) { m.0 >= cutoff_2h })
  let recent_count = list.length(recent)

  // Unique sources in 2h window
  let source_set =
    list.fold(recent, set.new(), fn(s, m) { set.insert(s, m.1) })
  let source_count = set.size(source_set)

  // 7d baseline: mentions older than 2h but within 7d
  let cutoff_7d = now - seven_days_ms
  let baseline_window =
    list.filter(entry.mentions, fn(m) {
      m.0 >= cutoff_7d && m.0 < cutoff_2h
    })
  // baseline_rate = mentions per 2h over 7d baseline window
  // 7 days = 84 two-hour buckets; use actual 5-day window (60 buckets) for stability
  let baseline_rate = case list.length(baseline_window) {
    0 -> 0.0
    n -> int_to_float(n) /. 84.0
  }

  case
    !in_cooldown
    && recent_count >= min_recent_count
    && source_count >= min_source_count
  {
    False -> #(entry, Error(Nil))
    True -> {
      let multiplier = case baseline_rate >. 0.0 {
        True -> int_to_float(recent_count) /. baseline_rate
        False -> int_to_float(recent_count)
      }
      case multiplier >=. min_multiplier {
        False -> #(entry, Error(Nil))
        True -> {
          let raw_confidence =
            base_confidence +. { multiplier -. min_multiplier } *. confidence_per_mult
          let confidence =
            float.clamp(raw_confidence, min: base_confidence, max: max_confidence)
          let spike =
            Spike(
              keyword: keyword,
              recent_count: recent_count,
              baseline_rate: baseline_rate,
              multiplier: multiplier,
              source_count: source_count,
              confidence: confidence,
            )
          let updated = KeywordEntry(..entry, last_spike_at: now)
          #(updated, Ok(spike))
        }
      }
    }
  }
}

@external(erlang, "erlang", "float")
fn int_to_float(n: Int) -> Float
