import gleeunit
import gleeunit/should
import zeitgeist/llm/pool.{PoolConfig}
import zeitgeist/llm/types.{LlmRequest, MockProvider, Normal}

pub fn main() {
  gleeunit.main()
}

pub fn pool_start_test() {
  let config =
    PoolConfig(
      default_provider: MockProvider,
      fallback_provider: MockProvider,
      max_concurrent: 4,
    )
  let result = pool.start(config)
  should.be_ok(result)
  let assert Ok(p) = result
  pool.stop(p)
}

pub fn pool_complete_mock_request_test() {
  let config =
    PoolConfig(
      default_provider: MockProvider,
      fallback_provider: MockProvider,
      max_concurrent: 4,
    )
  let assert Ok(p) = pool.start(config)

  let req =
    LlmRequest(
      prompt: "Assess the risk in this region",
      system: "",
      provider: MockProvider,
      max_tokens: 256,
      temperature: 0.7,
      priority: Normal,
    )
  let result = pool.complete(p, req)
  should.be_ok(result)
  let assert Ok(resp) = result
  should.be_true(resp.content != "")

  pool.stop(p)
}

pub fn pool_tracks_stats_test() {
  let config =
    PoolConfig(
      default_provider: MockProvider,
      fallback_provider: MockProvider,
      max_concurrent: 4,
    )
  let assert Ok(p) = pool.start(config)

  let req =
    LlmRequest(
      prompt: "predict geopolitical scenario",
      system: "",
      provider: MockProvider,
      max_tokens: 256,
      temperature: 0.7,
      priority: Normal,
    )

  // Make 3 requests
  let _ = pool.complete(p, req)
  let _ = pool.complete(p, req)
  let _ = pool.complete(p, req)

  let stats = pool.get_stats(p)
  should.equal(stats.total_requests, 3)
  should.equal(stats.successes, 3)
  should.equal(stats.failures, 0)

  pool.stop(p)
}
