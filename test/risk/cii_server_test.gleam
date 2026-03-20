import gleam/erlang/process
import gleam/list
import gleeunit
import gleeunit/should
import zeitgeist/core/bus
import zeitgeist/risk/cii_server

pub fn main() {
  gleeunit.main()
}

pub fn get_unknown_country_test() {
  let assert Ok(b) = bus.start()
  let assert Ok(server) = cii_server.start(b)
  let risk = cii_server.get_country(server, "XX")
  risk.country_code |> should.equal("XX")
  risk.cii_score |> should.equal(0.0)
  cii_server.stop(server)
}

pub fn update_score_test() {
  let assert Ok(b) = bus.start()
  let assert Ok(server) = cii_server.start(b)
  cii_server.update_country(server, "SY", 80.0)
  process.sleep(50)
  let risk = cii_server.get_country(server, "SY")
  let assert True = risk.cii_score >. 0.0
  cii_server.stop(server)
}

pub fn set_floor_enforcement_test() {
  let assert Ok(b) = bus.start()
  let assert Ok(server) = cii_server.start(b)
  cii_server.set_floor(server, "UA", 70.0)
  cii_server.update_country(server, "UA", 10.0)
  process.sleep(50)
  let risk = cii_server.get_country(server, "UA")
  let assert True = risk.cii_score >=. 70.0
  cii_server.stop(server)
}

pub fn list_countries_test() {
  let assert Ok(b) = bus.start()
  let assert Ok(server) = cii_server.start(b)
  cii_server.update_country(server, "US", 50.0)
  cii_server.update_country(server, "RU", 60.0)
  process.sleep(50)
  let countries = cii_server.list_countries(server)
  list.length(countries) |> should.equal(2)
  cii_server.stop(server)
}
