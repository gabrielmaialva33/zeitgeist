import gleam/string
import gleeunit
import gleeunit/should
import zeitgeist/llm/mock
import zeitgeist/llm/types.{LlmRequest, MockProvider, Normal}

pub fn main() {
  gleeunit.main()
}

pub fn mock_complete_returns_ok_test() {
  let req =
    LlmRequest(
      prompt: "What is the current world tension?",
      system: "",
      provider: MockProvider,
      max_tokens: 256,
      temperature: 0.7,
      priority: Normal,
    )
  let result = mock.complete(req)
  should.be_ok(result)
}

pub fn mock_complete_risk_context_test() {
  let req =
    LlmRequest(
      prompt: "Assess risk for this region",
      system: "",
      provider: MockProvider,
      max_tokens: 256,
      temperature: 0.7,
      priority: Normal,
    )
  let assert Ok(resp) = mock.complete(req)
  should.be_true(string.contains(string.lowercase(resp.content), "risk"))
}

pub fn mock_complete_predict_context_test() {
  let req =
    LlmRequest(
      prompt: "predict the next diplomatic move",
      system: "",
      provider: MockProvider,
      max_tokens: 256,
      temperature: 0.7,
      priority: Normal,
    )
  let assert Ok(resp) = mock.complete(req)
  should.be_true(string.contains(string.lowercase(resp.content), "predict"))
}

pub fn mock_complete_default_context_test() {
  let req =
    LlmRequest(
      prompt: "Summarize recent events",
      system: "",
      provider: MockProvider,
      max_tokens: 256,
      temperature: 0.7,
      priority: Normal,
    )
  let assert Ok(resp) = mock.complete(req)
  should.be_true(resp.content != "")
  should.equal(resp.provider, "mock")
}

pub fn mock_agent_decision_test() {
  let result = mock.agent_decision("agent1", "diplomatic", "high tension")
  should.be_true(result != "")
}

pub fn mock_react_step_test() {
  let result =
    mock.react_step(
      "What diplomatic action should be taken?",
      "High tension detected in region X",
    )
  should.be_true(result != "")
}
