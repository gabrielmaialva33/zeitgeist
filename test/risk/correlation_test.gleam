import gleeunit
import gleeunit/should
import zeitgeist/core/entity
import zeitgeist/core/event
import zeitgeist/risk/correlation

pub fn main() {
  gleeunit.main()
}

pub fn velocity_spike_detected_test() {
  correlation.check_velocity_spike(15.0, 4.0, 3.0) |> should.equal(True)
}

pub fn velocity_spike_not_detected_test() {
  correlation.check_velocity_spike(5.0, 4.0, 3.0) |> should.equal(False)
}

pub fn velocity_spike_zero_baseline_test() {
  correlation.check_velocity_spike(100.0, 0.0, 3.0) |> should.equal(False)
}

pub fn triangulation_detected_test() {
  let iran = entity.EntityRef(id: "iran", kind: entity.Government, name: "Iran")

  let news_event =
    event.Event(
      ..event.new(
        "e1",
        event.NewsArticle(
          title: "Iran",
          summary: "conflict",
          category: event.Conflict,
        ),
      ),
      entities: [iran],
      timestamp: 1000,
    )

  let military_event =
    event.Event(
      ..event.new(
        "e2",
        event.MilitaryTrack(
          track_type: event.Aircraft,
          callsign: "IR001",
          heading: 270.0,
        ),
      ),
      entities: [iran],
      timestamp: 1001,
    )

  let market_event =
    event.Event(
      ..event.new(
        "e3",
        event.MarketTick(symbol: "OIL", price: 95.0, change_pct: 4.2),
      ),
      entities: [iran],
      timestamp: 1002,
    )

  let events = [news_event, military_event, market_event]
  correlation.check_triangulation(events, "iran", 3) |> should.equal(True)
}

pub fn triangulation_not_detected_test() {
  let iran = entity.EntityRef(id: "iran", kind: entity.Government, name: "Iran")

  let news1 =
    event.Event(
      ..event.new(
        "e1",
        event.NewsArticle(
          title: "Iran strikes",
          summary: "military action",
          category: event.Conflict,
        ),
      ),
      entities: [iran],
      timestamp: 1000,
    )

  let news2 =
    event.Event(
      ..event.new(
        "e2",
        event.NewsArticle(
          title: "Iran tensions",
          summary: "politics",
          category: event.Politics,
        ),
      ),
      entities: [iran],
      timestamp: 1001,
    )

  // only 1 unique stream (NewsStream), need 3
  let events = [news1, news2]
  correlation.check_triangulation(events, "iran", 3) |> should.equal(False)
}
