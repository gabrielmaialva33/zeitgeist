// Ollama LLM provider — calls local Ollama /api/generate endpoint
import gleam/dynamic/decode
import gleam/json
import gleam/string
import zeitgeist/llm/types.{
  type LlmError, type LlmRequest, type LlmResponse, LlmNetworkError,
  LlmParseError, LlmResponse, OllamaProvider,
}

// ---------------------------------------------------------------------------
// FFI
// ---------------------------------------------------------------------------

@external(erlang, "zeitgeist_http_ffi", "http_post")
fn http_post(
  url: String,
  body: String,
  content_type: String,
  timeout_ms: Int,
) -> Result(String, String)

@external(erlang, "zeitgeist_ets_ffi", "now_ms")
fn now_ms() -> Int

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn complete(req: LlmRequest) -> Result(LlmResponse, LlmError) {
  case req.provider {
    OllamaProvider(base_url, model) -> do_complete(req, base_url, model)
    _ -> Error(LlmNetworkError("ollama", "wrong provider type"))
  }
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

fn do_complete(
  req: LlmRequest,
  base_url: String,
  model: String,
) -> Result(LlmResponse, LlmError) {
  let url = base_url <> "/api/generate"
  let body = build_request_body(req, model)
  let t0 = now_ms()
  case http_post(url, body, "application/json", 30_000) {
    Ok(resp_body) -> {
      let t1 = now_ms()
      parse_response(resp_body, model, t1 - t0)
    }
    Error(reason) -> Error(LlmNetworkError("ollama", reason))
  }
}

fn build_request_body(req: LlmRequest, model: String) -> String {
  let system_field = case req.system {
    "" -> []
    s -> [#("system", json.string(s))]
  }
  let fields =
    [#("model", json.string(model)), #("prompt", json.string(req.prompt)), #("stream", json.bool(False))]
    |> list_append(system_field)
  json.object(fields) |> json.to_string
}

fn list_append(a: List(a), b: List(a)) -> List(a) {
  case b {
    [] -> a
    [x, ..rest] -> list_append([x, ..a], rest)
  }
}

fn parse_response(
  body: String,
  model: String,
  latency_ms: Int,
) -> Result(LlmResponse, LlmError) {
  let decoder = {
    use content <- decode.field("response", decode.string)
    decode.success(content)
  }
  case json.parse(body, decoder) {
    Ok(content) -> {
      Ok(LlmResponse(
        content: content,
        provider: "ollama",
        model: model,
        prompt_tokens: 0,
        completion_tokens: string.length(content) / 4,
        latency_ms: latency_ms,
      ))
    }
    Error(_) -> Error(LlmParseError("ollama", body))
  }
}
