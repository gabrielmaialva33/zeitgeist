import gleam/list
import gleeunit
import gleeunit/should
import zeitgeist/risk/theater.{
  Awacs, Critical, Elevated, Fighter, Normal, Recon, Tanker,
}

pub fn main() {
  gleeunit.main()
}

pub fn default_posture_normal_test() {
  let t = theater.new("iran_gulf")
  t.posture |> should.equal(Normal)
  t.activity_count |> should.equal(0)
}

pub fn elevated_threshold_test() {
  let t = theater.new("iran_gulf") |> theater.add_activity(8)
  t.posture |> should.equal(Elevated)
}

pub fn critical_threshold_test() {
  let t = theater.new("iran_gulf") |> theater.add_activity(20)
  t.posture |> should.equal(Critical)
}

pub fn taiwan_thresholds_test() {
  let t_elevated = theater.new("taiwan_strait") |> theater.add_activity(6)
  t_elevated.posture |> should.equal(Elevated)

  let t_critical = theater.new("taiwan_strait") |> theater.add_activity(15)
  t_critical.posture |> should.equal(Critical)
}

pub fn strike_capable_test() {
  let t =
    theater.new("iran_gulf")
    |> theater.record_asset(Tanker)
    |> theater.record_asset(Awacs)
    |> theater.record_asset(Fighter)
    |> theater.record_asset(Fighter)
    |> theater.record_asset(Fighter)

  theater.is_strike_capable(t) |> should.equal(True)
}

pub fn not_strike_capable_without_awacs_test() {
  let t =
    theater.new("iran_gulf")
    |> theater.record_asset(Tanker)
    |> theater.record_asset(Fighter)
    |> theater.record_asset(Fighter)
    |> theater.record_asset(Fighter)

  theater.is_strike_capable(t) |> should.equal(False)
}

pub fn not_strike_capable_without_tanker_test() {
  let t =
    theater.new("iran_gulf")
    |> theater.record_asset(Awacs)
    |> theater.record_asset(Fighter)
    |> theater.record_asset(Fighter)
    |> theater.record_asset(Fighter)

  theater.is_strike_capable(t) |> should.equal(False)
}

pub fn not_strike_capable_too_few_fighters_test() {
  let t =
    theater.new("iran_gulf")
    |> theater.record_asset(Tanker)
    |> theater.record_asset(Awacs)
    |> theater.record_asset(Fighter)
    |> theater.record_asset(Fighter)

  theater.is_strike_capable(t) |> should.equal(False)
}

pub fn all_nine_theaters_exist_test() {
  let ids = theater.all_theater_ids()
  list.length(ids) |> should.equal(9)
  let assert True = list.contains(ids, "iran_gulf")
  let assert True = list.contains(ids, "taiwan_strait")
  let assert True = list.contains(ids, "baltic")
  let assert True = list.contains(ids, "black_sea")
  let assert True = list.contains(ids, "korea")
  let assert True = list.contains(ids, "south_china_sea")
  let assert True = list.contains(ids, "east_med")
  let assert True = list.contains(ids, "israel_gaza")
  let assert True = list.contains(ids, "yemen_red_sea")
}

pub fn record_asset_appends_test() {
  let t =
    theater.new("baltic")
    |> theater.record_asset(Recon)
    |> theater.record_asset(Tanker)

  list.length(t.assets) |> should.equal(2)
}

pub fn activity_accumulates_test() {
  let t =
    theater.new("black_sea")
    |> theater.add_activity(3)
    |> theater.add_activity(2)

  t.activity_count |> should.equal(5)
  t.posture |> should.equal(Elevated)
}
