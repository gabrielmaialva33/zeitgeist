import gleam/int

pub type TemporalLevel {
  Year(year: Int)
  Month(year: Int, month: Int)
  Day(year: Int, month: Int, day: Int)
  Hour(year: Int, month: Int, day: Int, hour: Int)
}

pub fn hour_level(timestamp_ms: Int) -> TemporalLevel {
  let #(year, month, day, hour, _, _) = timestamp_to_parts(timestamp_ms)
  Hour(year, month, day, hour)
}

pub fn day_level(timestamp_ms: Int) -> TemporalLevel {
  let #(year, month, day, _, _, _) = timestamp_to_parts(timestamp_ms)
  Day(year, month, day)
}

pub fn month_level(timestamp_ms: Int) -> TemporalLevel {
  let #(year, month, _, _, _, _) = timestamp_to_parts(timestamp_ms)
  Month(year, month)
}

pub fn level_key(level: TemporalLevel) -> String {
  case level {
    Year(y) -> int.to_string(y)
    Month(y, m) -> int.to_string(y) <> "-" <> pad2(m)
    Day(y, m, d) -> int.to_string(y) <> "-" <> pad2(m) <> "-" <> pad2(d)
    Hour(y, m, d, h) ->
      int.to_string(y)
      <> "-"
      <> pad2(m)
      <> "-"
      <> pad2(d)
      <> "-"
      <> pad2(h)
  }
}

fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}

@external(erlang, "zeitgeist_ets_ffi", "unix_ms_to_parts")
fn timestamp_to_parts(timestamp_ms: Int) -> #(Int, Int, Int, Int, Int, Int)
