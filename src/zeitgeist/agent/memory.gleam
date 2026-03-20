import gleam/float
import gleam/list
import zeitgeist/agent/action.{type AgentActionType}
import zeitgeist/graph/fact.{type AtomicFact}

pub type AgentMemory {
  AgentMemory(
    known_facts: List(AtomicFact),
    max_facts: Int,
    action_history: List(#(Int, AgentActionType)),
    current_sentiment: Float,
  )
}

pub fn new(max_facts: Int) -> AgentMemory {
  AgentMemory(
    known_facts: [],
    max_facts: max_facts,
    action_history: [],
    current_sentiment: 0.0,
  )
}

pub fn add_fact(mem: AgentMemory, fact: AtomicFact) -> AgentMemory {
  let updated = [fact, ..mem.known_facts] |> list.take(mem.max_facts)
  AgentMemory(..mem, known_facts: updated)
}

pub fn record_action(
  mem: AgentMemory,
  timestamp: Int,
  act: AgentActionType,
) -> AgentMemory {
  let updated = [#(timestamp, act), ..mem.action_history]
  AgentMemory(..mem, action_history: updated)
}

pub fn adjust_sentiment(mem: AgentMemory, delta: Float) -> AgentMemory {
  let new_s =
    float.clamp(mem.current_sentiment +. delta, min: -1.0, max: 1.0)
  AgentMemory(..mem, current_sentiment: new_s)
}

pub fn fact_count(mem: AgentMemory) -> Int {
  list.length(mem.known_facts)
}

pub fn action_count(mem: AgentMemory) -> Int {
  list.length(mem.action_history)
}

pub fn sentiment(mem: AgentMemory) -> Float {
  mem.current_sentiment
}
