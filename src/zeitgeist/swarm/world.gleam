import zeitgeist/agent/types

// ---------------------------------------------------------------------------
// Event seed type
// ---------------------------------------------------------------------------

pub type Event {
  Event(id: String, description: String, tension_delta: Float)
}

// ---------------------------------------------------------------------------
// World
// ---------------------------------------------------------------------------

pub type World {
  World(
    id: String,
    name: String,
    seed_events: List(Event),
    tick: Int,
    tick_interval_ms: Int,
    agent_ids: List(String),
    state: types.WorldState,
    max_ticks: Int,
    world_tension: Float,
  )
}

pub fn new(
  id: String,
  name: String,
  max_ticks: Int,
  tick_interval_ms: Int,
) -> World {
  World(
    id: id,
    name: name,
    seed_events: [],
    tick: 0,
    tick_interval_ms: tick_interval_ms,
    agent_ids: [],
    state: types.Running,
    max_ticks: max_ticks,
    world_tension: 0.5,
  )
}
