// LLM abstraction layer — pure types, no IO

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

pub type LlmProvider {
  MockProvider
  OllamaProvider(base_url: String, model: String)
  AnthropicProvider(api_key: String, model: String)
  OpenAiProvider(api_key: String, model: String)
  GroqProvider(api_key: String, model: String)
}

pub fn provider_name(provider: LlmProvider) -> String {
  case provider {
    MockProvider -> "mock"
    OllamaProvider(_, model) -> "ollama:" <> model
    AnthropicProvider(_, model) -> "anthropic:" <> model
    OpenAiProvider(_, model) -> "openai:" <> model
    GroqProvider(_, model) -> "groq:" <> model
  }
}

// ---------------------------------------------------------------------------
// Request
// ---------------------------------------------------------------------------

pub type RequestPriority {
  Low
  Normal
  High
}

pub type LlmRequest {
  LlmRequest(
    prompt: String,
    system: String,
    provider: LlmProvider,
    max_tokens: Int,
    temperature: Float,
    priority: RequestPriority,
  )
}

pub fn new_request(prompt: String, provider: LlmProvider) -> LlmRequest {
  LlmRequest(
    prompt: prompt,
    system: "",
    provider: provider,
    max_tokens: 256,
    temperature: 0.7,
    priority: Normal,
  )
}

// ---------------------------------------------------------------------------
// Response
// ---------------------------------------------------------------------------

pub type LlmResponse {
  LlmResponse(
    content: String,
    provider: String,
    model: String,
    prompt_tokens: Int,
    completion_tokens: Int,
    latency_ms: Int,
  )
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

pub type LlmError {
  LlmNetworkError(provider: String, reason: String)
  LlmParseError(provider: String, raw: String)
  LlmTimeout(provider: String, timeout_ms: Int)
  LlmRateLimited(provider: String, retry_after_ms: Int)
  LlmUnknownError(provider: String, reason: String)
  AllProvidersFailed(primary_error: String, fallback_error: String)
}
