// LLM Pool GenServer — dispatches requests, tracks stats, supports fallback
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import zeitgeist/llm/mock
import zeitgeist/llm/ollama
import zeitgeist/llm/types.{
  type LlmError, type LlmProvider, type LlmRequest, type LlmResponse,
  AllProvidersFailed, MockProvider, OllamaProvider,
}

// ---------------------------------------------------------------------------
// Config & Stats
// ---------------------------------------------------------------------------

pub type PoolConfig {
  PoolConfig(
    default_provider: LlmProvider,
    fallback_provider: LlmProvider,
    max_concurrent: Int,
  )
}

pub type PoolStats {
  PoolStats(total_requests: Int, successes: Int, failures: Int)
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

pub type PoolMsg {
  Complete(
    req: LlmRequest,
    reply_to: Subject(Result(LlmResponse, LlmError)),
  )
  GetStats(reply_to: Subject(PoolStats))
  PoolStop
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

type PoolState {
  PoolState(
    config: PoolConfig,
    total_requests: Int,
    successes: Int,
    failures: Int,
  )
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn start(config: PoolConfig) -> Result(Subject(PoolMsg), actor.StartError) {
  let init_state =
    PoolState(
      config: config,
      total_requests: 0,
      successes: 0,
      failures: 0,
    )
  let r =
    actor.new(init_state)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn stop(pool: Subject(PoolMsg)) -> Nil {
  process.send(pool, PoolStop)
}

pub fn complete(
  pool: Subject(PoolMsg),
  req: LlmRequest,
) -> Result(LlmResponse, LlmError) {
  process.call(pool, waiting: 30_000, sending: fn(reply_to) {
    Complete(req: req, reply_to: reply_to)
  })
}

pub fn get_stats(pool: Subject(PoolMsg)) -> PoolStats {
  process.call(pool, waiting: 5000, sending: fn(reply_to) {
    GetStats(reply_to: reply_to)
  })
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

fn handle_message(
  state: PoolState,
  msg: PoolMsg,
) -> actor.Next(PoolState, PoolMsg) {
  case msg {
    Complete(req, reply_to) -> {
      // Override request provider with pool's default
      let req_with_default =
        types.LlmRequest(..req, provider: state.config.default_provider)
      let result = dispatch(req_with_default)
      let #(result2, new_state) = case result {
        Ok(_) -> {
          #(result, PoolState(
            ..state,
            total_requests: state.total_requests + 1,
            successes: state.successes + 1,
          ))
        }
        Error(primary_err) -> {
          // Try fallback
          let fallback_req =
            types.LlmRequest(..req, provider: state.config.fallback_provider)
          case dispatch(fallback_req) {
            Ok(resp) -> {
              #(Ok(resp), PoolState(
                ..state,
                total_requests: state.total_requests + 1,
                successes: state.successes + 1,
              ))
            }
            Error(fallback_err) -> {
              let err =
                AllProvidersFailed(
                  primary_error: error_to_string(primary_err),
                  fallback_error: error_to_string(fallback_err),
                )
              #(Error(err), PoolState(
                ..state,
                total_requests: state.total_requests + 1,
                failures: state.failures + 1,
              ))
            }
          }
        }
      }
      process.send(reply_to, result2)
      actor.continue(new_state)
    }

    GetStats(reply_to) -> {
      let stats =
        PoolStats(
          total_requests: state.total_requests,
          successes: state.successes,
          failures: state.failures,
        )
      process.send(reply_to, stats)
      actor.continue(state)
    }

    PoolStop -> actor.stop()
  }
}

// ---------------------------------------------------------------------------
// Dispatch
// ---------------------------------------------------------------------------

fn dispatch(req: LlmRequest) -> Result(LlmResponse, LlmError) {
  case req.provider {
    MockProvider -> mock.complete(req)
    OllamaProvider(_, _) -> ollama.complete(req)
    _ -> mock.complete(req)
  }
}

fn error_to_string(err: LlmError) -> String {
  case err {
    types.LlmNetworkError(provider, reason) ->
      "network_error(" <> provider <> "): " <> reason
    types.LlmParseError(provider, _) -> "parse_error(" <> provider <> ")"
    types.LlmTimeout(provider, _) -> "timeout(" <> provider <> ")"
    types.LlmRateLimited(provider, _) -> "rate_limited(" <> provider <> ")"
    types.LlmUnknownError(provider, reason) ->
      "unknown_error(" <> provider <> "): " <> reason
    AllProvidersFailed(primary, fallback) ->
      "all_failed: " <> primary <> " / " <> fallback
  }
}
