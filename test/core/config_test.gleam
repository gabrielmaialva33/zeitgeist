import gleeunit
import gleeunit/should
import zeitgeist/core/config

pub fn main() {
  gleeunit.main()
}

pub fn default_config_test() {
  let c = config.default()
  c.http_port |> should.equal(4000)
  c.snapshot_interval_ms |> should.equal(300_000)
  c.high_watermark |> should.equal(0.8)
}
