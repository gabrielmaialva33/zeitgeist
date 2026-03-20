import gleam/float

pub type GeoPoint {
  GeoPoint(lat: Float, lon: Float)
}

const earth_radius_km = 6371.0

const pi = 3.14159265358979323846

fn to_radians(degrees: Float) -> Float {
  degrees *. pi /. 180.0
}

pub fn haversine_km(a: GeoPoint, b: GeoPoint) -> Float {
  let dlat = to_radians(b.lat -. a.lat)
  let dlon = to_radians(b.lon -. a.lon)
  let lat1 = to_radians(a.lat)
  let lat2 = to_radians(b.lat)

  let sin_dlat = sin(dlat /. 2.0)
  let sin_dlon = sin(dlon /. 2.0)

  let h = sin_dlat *. sin_dlat +. cos(lat1) *. cos(lat2) *. sin_dlon *. sin_dlon

  let assert Ok(sqrt_h) = float.square_root(h)
  let assert Ok(sqrt_1mh) = float.square_root(1.0 -. h)

  2.0 *. earth_radius_km *. atan2(sqrt_h, sqrt_1mh)
}

@external(erlang, "math", "sin")
fn sin(x: Float) -> Float

@external(erlang, "math", "cos")
fn cos(x: Float) -> Float

@external(erlang, "math", "atan2")
fn atan2(y: Float, x: Float) -> Float
