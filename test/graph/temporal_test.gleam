import gleeunit
import gleeunit/should
import zeitgeist/graph/temporal

pub fn main() {
  gleeunit.main()
}

pub fn level_from_timestamp_test() {
  // 2026-03-20 14:30:00 UTC = 1774017000 seconds
  let ts = 1_774_017_000_000
  let hour = temporal.hour_level(ts)
  case hour {
    temporal.Hour(2026, 3, 20, 14) -> should.be_ok(Ok(Nil))
    _ -> should.fail()
  }
}

pub fn level_key_test() {
  let level = temporal.Hour(2026, 3, 20, 14)
  temporal.level_key(level) |> should.equal("2026-03-20-14")
}

pub fn day_level_test() {
  // 2026-03-20 14:30:00 UTC = 1774017000 seconds
  let ts = 1_774_017_000_000
  let day = temporal.day_level(ts)
  case day {
    temporal.Day(2026, 3, 20) -> should.be_ok(Ok(Nil))
    _ -> should.fail()
  }
}
