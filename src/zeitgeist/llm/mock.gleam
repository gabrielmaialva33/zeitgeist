// Mock LLM provider — always succeeds, context-aware canned responses
import gleam/string
import zeitgeist/llm/types.{
  type LlmError, type LlmRequest, type LlmResponse, LlmResponse,
}

// ---------------------------------------------------------------------------
// FFI
// ---------------------------------------------------------------------------

@external(erlang, "zeitgeist_ets_ffi", "now_ms")
fn now_ms() -> Int

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Always returns Ok. Context-aware responses based on prompt keywords.
pub fn complete(req: LlmRequest) -> Result(LlmResponse, LlmError) {
  let t0 = now_ms()
  let prompt_lower = string.lowercase(req.prompt)
  let content = pick_response(prompt_lower)
  let t1 = now_ms()
  let resp =
    LlmResponse(
      content: content,
      provider: "mock",
      model: "mock-v1",
      prompt_tokens: string.length(req.prompt) / 4,
      completion_tokens: string.length(content) / 4,
      latency_ms: t1 - t0,
    )
  Ok(resp)
}

/// Returns a deterministic decision string for an agent.
pub fn agent_decision(
  agent_id: String,
  kind: String,
  context: String,
) -> String {
  "Agent "
  <> agent_id
  <> " decision ["
  <> kind
  <> "]: Based on context '"
  <> context
  <> "', recommend cautious diplomatic engagement."
}

/// Returns a ReACT-style reasoning step.
pub fn react_step(question: String, observation: String) -> String {
  "Thought: I need to predict the outcome based on available evidence.\n"
  <> "Observation: "
  <> observation
  <> "\n"
  <> "Action: analyze_diplomatic_context("
  <> question
  <> ")\n"
  <> "Answer: Based on the observation, a measured response is advised."
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

fn pick_response(prompt_lower: String) -> String {
  case
    string.contains(prompt_lower, "risk")
    || string.contains(prompt_lower, "threat")
    || string.contains(prompt_lower, "danger")
  {
    True ->
      "Risk assessment complete: elevated risk detected in the specified region. "
      <> "Current indicators suggest moderate-to-high probability of escalation. "
      <> "Recommend monitoring and contingency planning."
    False ->
      case
        string.contains(prompt_lower, "predict")
        || string.contains(prompt_lower, "forecast")
        || string.contains(prompt_lower, "scenario")
      {
        True ->
          "Prediction analysis: based on current geopolitical trends, "
          <> "the most likely scenario involves diplomatic negotiations. "
          <> "Confidence: 0.72. Horizon: 48 hours."
        False ->
          "Analysis complete: the situation remains dynamic. "
          <> "Key factors include regional stability indices, economic indicators, "
          <> "and diplomatic communications. Recommend continued monitoring."
      }
  }
}
