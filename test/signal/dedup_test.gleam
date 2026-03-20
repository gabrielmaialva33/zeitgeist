import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/core/event
import zeitgeist/signal/dedup

pub fn main() {
  gleeunit.main()
}

fn news(id: String, title: String, ts: Int) -> event.Event {
  event.Event(
    id: id,
    timestamp: ts,
    kind: event.NewsArticle(
      title: title,
      summary: "some summary",
      category: event.General,
    ),
    source: event.RealWorld("src1"),
    location: None,
    entities: [],
    confidence: 0.9,
    raw: None,
  )
}

pub fn fingerprint_determinism_test() {
  let e = news("e1", "Breaking: War in region X", 1000)
  let fp1 = dedup.fingerprint(e)
  let fp2 = dedup.fingerprint(e)
  fp1 |> should.equal(fp2)
}

pub fn fingerprint_same_content_same_hash_test() {
  let e1 = news("id_a", "Breaking: War in region X", 1000)
  let e2 = news("id_b", "Breaking: War in region X", 9999)
  // id and timestamp differ, but title+summary same → same fingerprint
  dedup.fingerprint(e1) |> should.equal(dedup.fingerprint(e2))
}

pub fn fingerprint_different_content_different_hash_test() {
  let e1 = news("e1", "Breaking: War in region X", 1000)
  let e2 = news("e2", "Markets rally 10%", 1000)
  let should_differ = dedup.fingerprint(e1) != dedup.fingerprint(e2)
  should_differ |> should.be_true
}

pub fn identical_is_duplicate_test() {
  let e = news("e1", "Breaking: War in region X", 1000)
  let existing = [e]
  let result = dedup.check(existing, e)
  result |> should.equal(dedup.Duplicate)
}

pub fn different_is_new_test() {
  let e1 = news("e1", "Breaking: War in region X", 1000)
  let e2 = news("e2", "Markets rally 10%", 2000)
  let existing = [e1]
  let result = dedup.check(existing, e2)
  result |> should.equal(dedup.New)
}

pub fn empty_existing_is_new_test() {
  let e = news("e1", "Some news", 1000)
  let result = dedup.check([], e)
  result |> should.equal(dedup.New)
}

fn news_with_summary(
  id: String,
  title: String,
  summary: String,
  ts: Int,
) -> event.Event {
  event.Event(
    id: id,
    timestamp: ts,
    kind: event.NewsArticle(
      title: title,
      summary: summary,
      category: event.General,
    ),
    source: event.RealWorld("src1"),
    location: None,
    entities: [],
    confidence: 0.9,
    raw: None,
  )
}

pub fn similar_title_within_2h_is_similar_test() {
  let base_ts = 1_000_000
  let two_hours_ms = 2 * 60 * 60 * 1000
  // e1: original article
  let e1 = news("e1", "War erupts in region X", base_ts)
  // e2: different casing in title (different fingerprint), within 2h → Similar
  let e2 = news_with_summary("e2", "war erupts in region x", "different body", base_ts + 10_000)
  let existing = [e1]
  let result = dedup.check(existing, e2)
  result |> should.equal(dedup.Similar)

  // e3: same normalized title but outside 2h window, different summary → New
  let e3 =
    news_with_summary(
      "e3",
      "War erupts in region X",
      "later report",
      base_ts + two_hours_ms + 1,
    )
  let result2 = dedup.check(existing, e3)
  result2 |> should.equal(dedup.New)
}
