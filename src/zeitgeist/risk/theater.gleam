import gleam/list

pub type TheaterPosture {
  Normal
  Elevated
  Critical
}

pub type AssetType {
  Tanker
  Awacs
  Fighter
  Bomber
  Drone
  Recon
  OtherAsset
}

pub type Theater {
  Theater(
    id: String,
    posture: TheaterPosture,
    activity_count: Int,
    elevated_threshold: Int,
    critical_threshold: Int,
    assets: List(AssetType),
  )
}

fn thresholds(theater_id: String) -> #(Int, Int) {
  case theater_id {
    "iran_gulf" -> #(8, 20)
    "taiwan_strait" -> #(6, 15)
    "baltic" -> #(5, 12)
    "black_sea" -> #(4, 10)
    "korea" -> #(5, 12)
    "south_china_sea" -> #(6, 15)
    "east_med" -> #(4, 10)
    "israel_gaza" -> #(3, 8)
    "yemen_red_sea" -> #(4, 10)
    _ -> #(5, 10)
  }
}

fn compute_posture(count: Int, elevated: Int, critical: Int) -> TheaterPosture {
  case count >= critical {
    True -> Critical
    False ->
      case count >= elevated {
        True -> Elevated
        False -> Normal
      }
  }
}

pub fn new(theater_id: String) -> Theater {
  let #(elevated, critical) = thresholds(theater_id)
  Theater(
    id: theater_id,
    posture: Normal,
    activity_count: 0,
    elevated_threshold: elevated,
    critical_threshold: critical,
    assets: [],
  )
}

pub fn add_activity(theater: Theater, count: Int) -> Theater {
  let new_count = theater.activity_count + count
  let posture =
    compute_posture(new_count, theater.elevated_threshold, theater.critical_threshold)
  Theater(..theater, activity_count: new_count, posture: posture)
}

pub fn record_asset(theater: Theater, asset: AssetType) -> Theater {
  Theater(..theater, assets: [asset, ..theater.assets])
}

pub fn is_strike_capable(theater: Theater) -> Bool {
  let tankers = list.count(theater.assets, fn(a) { a == Tanker })
  let awacs_count = list.count(theater.assets, fn(a) { a == Awacs })
  let fighters = list.count(theater.assets, fn(a) { a == Fighter })
  tankers >= 1 && awacs_count >= 1 && fighters >= 3
}

pub fn all_theater_ids() -> List(String) {
  [
    "iran_gulf",
    "taiwan_strait",
    "baltic",
    "black_sea",
    "korea",
    "south_china_sea",
    "east_med",
    "israel_gaza",
    "yemen_red_sea",
  ]
}
