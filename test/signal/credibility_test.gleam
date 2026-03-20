import gleeunit
import gleeunit/should
import zeitgeist/signal/credibility

pub fn main() {
  gleeunit.main()
}

pub fn initial_score_test() {
  let c = credibility.new("src1", 0.8)
  c.source_id |> should.equal("src1")
  c.base_score |> should.equal(0.8)
  // effective_score starts same as base_score
  c.effective_score |> should.equal(0.8)
}

pub fn recompute_formula_test() {
  let c = credibility.new("src1", 1.0)
  // accuracy=1.0, freshness=1.0, confirmation=1.0 → effective = 1.0*(0.4+0.3+0.3)=1.0
  let c2 = credibility.recompute(c)
  c2.effective_score |> should.equal(1.0)
}

pub fn recompute_partial_test() {
  // accuracy=0.5, freshness=0.5, confirmation=0.5
  // effective = base * (0.4*0.5 + 0.3*0.5 + 0.3*0.5) = base * 0.5
  let c =
    credibility.SourceCredibility(
      source_id: "src2",
      base_score: 1.0,
      accuracy: 0.5,
      freshness: 0.5,
      confirmation: 0.5,
      effective_score: 0.0,
    )
  let c2 = credibility.recompute(c)
  c2.effective_score |> should.equal(0.5)
}

pub fn confirmation_boost_test() {
  // start from a degraded source (accuracy=0.0) and verify boost
  let c =
    credibility.SourceCredibility(
      source_id: "src1",
      base_score: 1.0,
      accuracy: 0.0,
      freshness: 1.0,
      confirmation: 1.0,
      effective_score: 0.7,
    )
  let c2 = credibility.record_confirmation(c)
  // accuracy should increase via EMA from 0.0 toward 1.0
  let increased = c2.accuracy >. c.accuracy
  increased |> should.be_true
}

pub fn miss_degradation_test() {
  let c = credibility.new("src1", 1.0)
  let c2 = credibility.record_miss(c)
  // accuracy should decrease via EMA
  let decreased = c2.accuracy <. c.accuracy
  decreased |> should.be_true
}

pub fn multiple_confirmations_converge_test() {
  let c = credibility.new("src1", 1.0)
  // after many confirmations accuracy approaches 1.0
  let c2 =
    c
    |> credibility.record_confirmation
    |> credibility.record_confirmation
    |> credibility.record_confirmation
    |> credibility.record_confirmation
    |> credibility.record_confirmation
  let c3 = credibility.recompute(c2)
  let high = c3.effective_score >. 0.9
  high |> should.be_true
}

pub fn miss_then_confirm_test() {
  let c = credibility.new("src1", 1.0)
  let c2 =
    c
    |> credibility.record_miss
    |> credibility.record_miss
    |> credibility.record_confirmation
  let after_miss = credibility.record_miss(c) |> credibility.record_miss
  let mixed_gt_miss = c2.accuracy >. after_miss.accuracy
  mixed_gt_miss |> should.be_true
}
