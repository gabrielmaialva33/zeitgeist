import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import zeitgeist/core/bus.{type BusMsg}
import zeitgeist/risk/cii.{type CountryRisk}

pub type CiiMsg {
  UpdateCountry(country_code: String, event_score: Float)
  SetFloor(country_code: String, floor: Float)
  GetCountry(country_code: String, reply_to: Subject(CountryRisk))
  ListCountries(reply_to: Subject(List(CountryRisk)))
  Stop
}

type CiiState =
  Dict(String, CountryRisk)

pub fn start(
  bus: Subject(BusMsg),
) -> Result(Subject(CiiMsg), actor.StartError) {
  // bus param accepted but not subscribed in P1 (wired in Task 10)
  let _ = bus
  let r =
    actor.new(dict.new())
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn stop(server: Subject(CiiMsg)) -> Nil {
  process.send(server, Stop)
}

pub fn get_country(server: Subject(CiiMsg), code: String) -> CountryRisk {
  process.call(server, waiting: 5000, sending: fn(reply_to) {
    GetCountry(country_code: code, reply_to: reply_to)
  })
}

pub fn update_country(
  server: Subject(CiiMsg),
  code: String,
  event_score: Float,
) -> Nil {
  process.send(server, UpdateCountry(country_code: code, event_score: event_score))
}

pub fn set_floor(server: Subject(CiiMsg), code: String, floor: Float) -> Nil {
  process.send(server, SetFloor(country_code: code, floor: floor))
}

pub fn list_countries(server: Subject(CiiMsg)) -> List(CountryRisk) {
  process.call(server, waiting: 5000, sending: fn(reply_to) {
    ListCountries(reply_to: reply_to)
  })
}

fn handle_message(
  state: CiiState,
  msg: CiiMsg,
) -> actor.Next(CiiState, CiiMsg) {
  case msg {
    UpdateCountry(code, evt_score) -> {
      let current = case dict.get(state, code) {
        Ok(risk) -> risk
        Error(_) -> cii.new(code)
      }
      let updated = cii.update_score(current, evt_score)
      actor.continue(dict.insert(state, code, updated))
    }
    SetFloor(code, floor) -> {
      let current = case dict.get(state, code) {
        Ok(risk) -> risk
        Error(_) -> cii.new(code)
      }
      let updated = cii.set_floor(current, floor)
      actor.continue(dict.insert(state, code, updated))
    }
    GetCountry(code, reply_to) -> {
      let risk = case dict.get(state, code) {
        Ok(r) -> r
        Error(_) -> cii.new(code)
      }
      process.send(reply_to, risk)
      actor.continue(state)
    }
    ListCountries(reply_to) -> {
      let countries = dict.values(state)
      process.send(reply_to, countries)
      actor.continue(state)
    }
    Stop -> actor.stop()
  }
}
