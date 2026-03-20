import gleam/option.{type Option, None}

pub type Config {
  Config(
    http_port: Int,
    api_key: String,
    snapshot_interval_ms: Int,
    decay_sweep_interval_ms: Int,
    ollama_url: String,
    ollama_model: String,
    ollama_concurrency: Int,
    anthropic_api_key: Option(String),
    openai_api_key: Option(String),
    groq_api_key: Option(String),
    default_tick_interval_ms: Int,
    max_agents_per_world: Int,
    max_buffer_size: Int,
    high_watermark: Float,
    low_watermark: Float,
  )
}

pub fn default() -> Config {
  Config(
    http_port: 4000,
    api_key: "dev-key",
    snapshot_interval_ms: 300_000,
    decay_sweep_interval_ms: 3_600_000,
    ollama_url: "http://localhost:11434",
    ollama_model: "llama3.1:8b",
    ollama_concurrency: 30,
    anthropic_api_key: None,
    openai_api_key: None,
    groq_api_key: None,
    default_tick_interval_ms: 1000,
    max_agents_per_world: 5000,
    max_buffer_size: 10_000,
    high_watermark: 0.8,
    low_watermark: 0.3,
  )
}

pub fn load() -> Config {
  let d = default()
  Config(
    ..d,
    http_port: get_env_int("ZEITGEIST_PORT", d.http_port),
    api_key: get_env_string("ZEITGEIST_API_KEY", d.api_key),
    snapshot_interval_ms: get_env_int(
      "ZEITGEIST_SNAPSHOT_INTERVAL",
      d.snapshot_interval_ms,
    ),
    decay_sweep_interval_ms: get_env_int(
      "ZEITGEIST_DECAY_INTERVAL",
      d.decay_sweep_interval_ms,
    ),
    ollama_url: get_env_string("OLLAMA_URL", d.ollama_url),
    ollama_model: get_env_string("OLLAMA_MODEL", d.ollama_model),
    ollama_concurrency: get_env_int("OLLAMA_CONCURRENCY", d.ollama_concurrency),
  )
}

@external(erlang, "zeitgeist_config_ffi", "get_env_string")
fn get_env_string(name: String, default: String) -> String

@external(erlang, "zeitgeist_config_ffi", "get_env_int")
fn get_env_int(name: String, default: Int) -> Int
