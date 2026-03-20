import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import zeitgeist/core/entity.{type Entity}
import zeitgeist/core/ets
import zeitgeist/graph/fact.{type AtomicFact}
import zeitgeist/graph/temporal

pub type GraphMsg {
  UpsertEntity(entity: Entity)
  UpsertFact(fact: AtomicFact)
  GetEntity(id: String, reply_to: Subject(Result(Entity, Nil)))
  GetFact(id: String, reply_to: Subject(Result(AtomicFact, Nil)))
  EntityCount(reply_to: Subject(Int))
  FactCount(reply_to: Subject(Int))
  ListEntities(reply_to: Subject(List(Entity)))
  GetFactsByEntity(entity_id: String, reply_to: Subject(List(AtomicFact)))
  Stop
}

type GraphState {
  GraphState(
    entities: ets.EtsTable,
    facts: ets.EtsTable,
    temporal_idx: ets.EtsTable,
  )
}

pub fn start(prefix: String) -> Result(Subject(GraphMsg), actor.StartError) {
  let assert Ok(entities) = ets.new(prefix <> "_entities", "set")
  let assert Ok(facts) = ets.new(prefix <> "_facts", "set")
  let assert Ok(temporal_idx) = ets.new(prefix <> "_temporal", "set")
  let state =
    GraphState(entities: entities, facts: facts, temporal_idx: temporal_idx)

  let r =
    actor.new(state)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn stop(graph: Subject(GraphMsg)) -> Nil {
  process.send(graph, Stop)
}

pub fn upsert_entity(graph: Subject(GraphMsg), entity: Entity) -> Nil {
  process.send(graph, UpsertEntity(entity))
}

pub fn upsert_fact(graph: Subject(GraphMsg), fact: AtomicFact) -> Nil {
  process.send(graph, UpsertFact(fact))
}

pub fn get_entity(graph: Subject(GraphMsg), id: String) -> Result(Entity, Nil) {
  process.call(graph, waiting: 5000, sending: fn(reply_to) {
    GetEntity(id: id, reply_to: reply_to)
  })
}

pub fn get_fact(graph: Subject(GraphMsg), id: String) -> Result(AtomicFact, Nil) {
  process.call(graph, waiting: 5000, sending: fn(reply_to) {
    GetFact(id: id, reply_to: reply_to)
  })
}

pub fn entity_count(graph: Subject(GraphMsg)) -> Int {
  process.call(graph, waiting: 5000, sending: fn(reply_to) {
    EntityCount(reply_to: reply_to)
  })
}

pub fn fact_count(graph: Subject(GraphMsg)) -> Int {
  process.call(graph, waiting: 5000, sending: fn(reply_to) {
    FactCount(reply_to: reply_to)
  })
}

pub fn list_entities(graph: Subject(GraphMsg)) -> List(Entity) {
  process.call(graph, waiting: 5000, sending: fn(reply_to) {
    ListEntities(reply_to: reply_to)
  })
}

pub fn get_facts_by_entity(
  graph: Subject(GraphMsg),
  entity_id: String,
) -> List(AtomicFact) {
  process.call(graph, waiting: 5000, sending: fn(reply_to) {
    GetFactsByEntity(entity_id: entity_id, reply_to: reply_to)
  })
}

fn handle_message(
  state: GraphState,
  msg: GraphMsg,
) -> actor.Next(GraphState, GraphMsg) {
  case msg {
    UpsertEntity(entity) -> {
      ets.insert(state.entities, entity.id, entity)
      actor.continue(state)
    }
    UpsertFact(f) -> {
      ets.insert(state.facts, f.id, f)
      let hour_key = temporal.level_key(temporal.hour_level(f.observed_at))
      let idx_key = hour_key <> ":" <> f.subject
      ets.insert(state.temporal_idx, idx_key, f.id)
      actor.continue(state)
    }
    GetEntity(id, reply_to) -> {
      let result = case ets.lookup(state.entities, id) {
        Ok(dyn) -> Ok(coerce(dyn))
        Error(_) -> Error(Nil)
      }
      process.send(reply_to, result)
      actor.continue(state)
    }
    GetFact(id, reply_to) -> {
      let result = case ets.lookup(state.facts, id) {
        Ok(dyn) -> Ok(coerce(dyn))
        Error(_) -> Error(Nil)
      }
      process.send(reply_to, result)
      actor.continue(state)
    }
    EntityCount(reply_to) -> {
      process.send(reply_to, ets.size(state.entities))
      actor.continue(state)
    }
    FactCount(reply_to) -> {
      process.send(reply_to, ets.size(state.facts))
      actor.continue(state)
    }
    ListEntities(reply_to) -> {
      let entities =
        ets.lookup_all(state.entities)
        |> list.map(fn(dyn) { coerce(dyn) })
      process.send(reply_to, entities)
      actor.continue(state)
    }
    GetFactsByEntity(entity_id, reply_to) -> {
      let facts =
        ets.lookup_all(state.facts)
        |> list.map(fn(dyn) -> AtomicFact { coerce(dyn) })
        |> list.filter(fn(f) { f.subject == entity_id })
      process.send(reply_to, facts)
      actor.continue(state)
    }
    Stop -> actor.stop()
  }
}

@external(erlang, "zeitgeist_ets_ffi", "identity")
fn coerce(value: a) -> b
