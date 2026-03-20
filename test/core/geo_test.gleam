import gleeunit
import gleeunit/should
import zeitgeist/core/geo

pub fn main() {
  gleeunit.main()
}

pub fn haversine_same_point_test() {
  let p = geo.GeoPoint(lat: 40.7128, lon: -74.006)
  geo.haversine_km(p, p)
  |> should.equal(0.0)
}

pub fn haversine_new_york_to_london_test() {
  let ny = geo.GeoPoint(lat: 40.7128, lon: -74.006)
  let london = geo.GeoPoint(lat: 51.5074, lon: -0.1278)
  let distance = geo.haversine_km(ny, london)
  let assert True = distance >. 5520.0
  let assert True = distance <. 5620.0
}

pub fn haversine_short_distance_test() {
  let a = geo.GeoPoint(lat: 0.0, lon: 0.0)
  let b = geo.GeoPoint(lat: 0.0, lon: 1.0)
  let distance = geo.haversine_km(a, b)
  let assert True = distance >. 110.0
  let assert True = distance <. 112.0
}
