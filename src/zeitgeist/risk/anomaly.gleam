import gleam/float

@external(erlang, "erlang", "float")
fn int_to_float(n: Int) -> Float

pub type WelfordDetector {
  WelfordDetector(segment: String, count: Int, mean: Float, m2: Float)
}

pub type AnomalyLevel {
  Normal
  Elevated
  Critical
  ExtremeAnomaly
}

pub fn new_detector(segment: String) -> WelfordDetector {
  WelfordDetector(segment: segment, count: 0, mean: 0.0, m2: 0.0)
}

pub fn add_sample(d: WelfordDetector, value: Float) -> WelfordDetector {
  let new_count = d.count + 1
  let delta = value -. d.mean
  let new_mean = d.mean +. delta /. int_to_float(new_count)
  let delta2 = value -. new_mean
  let new_m2 = d.m2 +. delta *. delta2
  WelfordDetector(segment: d.segment, count: new_count, mean: new_mean, m2: new_m2)
}

pub fn z_score(d: WelfordDetector, value: Float) -> Float {
  case d.count < 10 {
    True -> 0.0
    False -> {
      let variance = d.m2 /. int_to_float(d.count)
      case float.square_root(variance) {
        Ok(std) if std >. 0.0 ->
          float.absolute_value({ value -. d.mean } /. std)
        _ -> 0.0
      }
    }
  }
}

pub fn classify(z: Float) -> AnomalyLevel {
  case z >=. 4.0 {
    True -> ExtremeAnomaly
    False ->
      case z >=. 3.0 {
        True -> Critical
        False ->
          case z >=. 2.0 {
            True -> Elevated
            False -> Normal
          }
      }
  }
}
