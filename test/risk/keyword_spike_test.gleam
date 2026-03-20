import gleam/list
import gleeunit
import gleeunit/should
import zeitgeist/risk/keyword_spike

pub fn main() {
  gleeunit.main()
}

pub fn extract_keywords_basic_test() {
  let words = keyword_spike.extract_keywords("The missile strike hit the port")
  // "the" and "hit" are stop words or too short; "missile" "strike" "port" should survive
  list.contains(words, "missile") |> should.equal(True)
  list.contains(words, "strike") |> should.equal(True)
  list.contains(words, "port") |> should.equal(True)
  // "the" is stop word
  list.contains(words, "the") |> should.equal(False)
}

pub fn extract_keywords_dedup_test() {
  let words =
    keyword_spike.extract_keywords("missile missile missile attack attack")
  // Should dedup
  let missile_count = list.length(list.filter(words, fn(w) { w == "missile" }))
  missile_count |> should.equal(1)
  let attack_count = list.length(list.filter(words, fn(w) { w == "attack" }))
  attack_count |> should.equal(1)
}

pub fn extract_keywords_punctuation_test() {
  let words =
    keyword_spike.extract_keywords("attack, forces. conflict! region?")
  list.contains(words, "attack") |> should.equal(True)
  list.contains(words, "forces") |> should.equal(True)
  list.contains(words, "conflict") |> should.equal(True)
  list.contains(words, "region") |> should.equal(True)
}

pub fn extract_keywords_length_filter_test() {
  let words = keyword_spike.extract_keywords("a an at big war zone")
  // "a", "an", "at" are < 3 chars
  list.contains(words, "a") |> should.equal(False)
  list.contains(words, "an") |> should.equal(False)
  list.contains(words, "at") |> should.equal(False)
  list.contains(words, "big") |> should.equal(True)
  list.contains(words, "war") |> should.equal(True)
}

pub fn no_spike_on_first_mention_test() {
  let tracker = keyword_spike.new_tracker()
  let ts = 1_000_000_000_000
  let #(_t, spikes) =
    keyword_spike.ingest(tracker, ["conflict"], "source_a", ts)
  // Only 1 mention, can't spike
  list.length(spikes) |> should.equal(0)
}

pub fn no_spike_below_threshold_test() {
  let tracker = keyword_spike.new_tracker()
  // Ingest 4 times (below min_recent_count=5) from different sources
  let ts = 1_000_000_000_000
  let #(t1, _) =
    keyword_spike.ingest(tracker, ["conflict"], "src_a", ts)
  let #(t2, _) =
    keyword_spike.ingest(t1, ["conflict"], "src_b", ts + 100)
  let #(t3, _) =
    keyword_spike.ingest(t2, ["conflict"], "src_c", ts + 200)
  let #(_t4, spikes) =
    keyword_spike.ingest(t3, ["conflict"], "src_d", ts + 300)
  // 4 mentions, need 5 minimum
  list.length(spikes) |> should.equal(0)
}

pub fn spike_after_threshold_test() {
  let tracker = keyword_spike.new_tracker()
  // Need >= 5 mentions in 2h window, >= 2 sources, multiplier >= 3
  // With no baseline, multiplier = recent_count (large), so it triggers
  let ts = 1_000_000_000_000
  let #(t1, _) =
    keyword_spike.ingest(tracker, ["missile"], "src_a", ts)
  let #(t2, _) =
    keyword_spike.ingest(t1, ["missile"], "src_a", ts + 1000)
  let #(t3, _) =
    keyword_spike.ingest(t2, ["missile"], "src_b", ts + 2000)
  let #(t4, _) =
    keyword_spike.ingest(t3, ["missile"], "src_b", ts + 3000)
  let #(_t5, spikes) =
    keyword_spike.ingest(t4, ["missile"], "src_c", ts + 4000)

  // Should have a spike for "missile"
  list.length(spikes) |> should.equal(1)
  let assert [spike] = spikes
  spike.keyword |> should.equal("missile")
  let assert True = spike.recent_count >= 5
  let assert True = spike.source_count >= 2
  let assert True = spike.confidence >=. 0.6
  let assert True = spike.confidence <=. 0.95
}

pub fn cooldown_prevents_duplicate_spike_test() {
  let tracker = keyword_spike.new_tracker()
  let ts = 1_000_000_000_000
  // Build up to first spike
  let #(t1, _) =
    keyword_spike.ingest(tracker, ["strike"], "src_a", ts)
  let #(t2, _) =
    keyword_spike.ingest(t1, ["strike"], "src_a", ts + 1000)
  let #(t3, _) =
    keyword_spike.ingest(t2, ["strike"], "src_b", ts + 2000)
  let #(t4, _) =
    keyword_spike.ingest(t3, ["strike"], "src_b", ts + 3000)
  let #(t5, spikes1) =
    keyword_spike.ingest(t4, ["strike"], "src_c", ts + 4000)

  // First spike should trigger
  list.length(spikes1) |> should.equal(1)

  // Immediately ingest more mentions (within 30 min cooldown = 1_800_000ms)
  let ts2 = ts + 60_000
  // 1 minute later — still in cooldown
  let #(t6, _) =
    keyword_spike.ingest(t5, ["strike"], "src_a", ts2)
  let #(t7, _) =
    keyword_spike.ingest(t6, ["strike"], "src_b", ts2 + 1000)
  let #(t8, _) =
    keyword_spike.ingest(t7, ["strike"], "src_c", ts2 + 2000)
  let #(t9, _) =
    keyword_spike.ingest(t8, ["strike"], "src_a", ts2 + 3000)
  let #(_t10, spikes2) =
    keyword_spike.ingest(t9, ["strike"], "src_b", ts2 + 4000)

  // Cooldown: no second spike
  list.length(spikes2) |> should.equal(0)
}

pub fn spike_confidence_clamped_test() {
  let tracker = keyword_spike.new_tracker()
  let ts = 1_000_000_000_000
  // Lots of mentions from many sources — multiplier very high
  let #(t1, _) =
    keyword_spike.ingest(tracker, ["war"], "s1", ts)
  let #(t2, _) =
    keyword_spike.ingest(t1, ["war"], "s2", ts + 100)
  let #(t3, _) =
    keyword_spike.ingest(t2, ["war"], "s3", ts + 200)
  let #(t4, _) =
    keyword_spike.ingest(t3, ["war"], "s4", ts + 300)
  let #(t5, _) =
    keyword_spike.ingest(t4, ["war"], "s5", ts + 400)
  let #(t6, _) =
    keyword_spike.ingest(t5, ["war"], "s6", ts + 500)
  let #(t7, _) =
    keyword_spike.ingest(t6, ["war"], "s7", ts + 600)
  let #(t8, _) =
    keyword_spike.ingest(t7, ["war"], "s8", ts + 700)
  let #(t9, _) =
    keyword_spike.ingest(t8, ["war"], "s9", ts + 800)
  let #(_t10, spikes) =
    keyword_spike.ingest(t9, ["war"], "s10", ts + 900)

  case spikes != [] {
    True -> {
      let assert [spike, ..] = spikes
      // Confidence must be clamped to [0.6, 0.95]
      let assert True = spike.confidence >=. 0.6
      let assert True = spike.confidence <=. 0.95
      Nil
    }
    False -> Nil
  }
}

pub fn multiple_keywords_independent_test() {
  let tracker = keyword_spike.new_tracker()
  let ts = 1_000_000_000_000
  let words = ["missile", "conflict"]

  let #(t1, _) = keyword_spike.ingest(tracker, words, "s1", ts)
  let #(t2, _) = keyword_spike.ingest(t1, words, "s1", ts + 100)
  let #(t3, _) = keyword_spike.ingest(t2, words, "s2", ts + 200)
  let #(t4, _) = keyword_spike.ingest(t3, words, "s2", ts + 300)
  let #(_t5, spikes) = keyword_spike.ingest(t4, words, "s3", ts + 400)

  // Both keywords should spike
  list.length(spikes) |> should.equal(2)
}
