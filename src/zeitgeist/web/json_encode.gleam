import gleam/int
import gleam/json.{type Json}
import gleam/list
import zeitgeist/agent/types
import zeitgeist/core/entity.{type Entity}
import zeitgeist/core/event.{type Event}
import zeitgeist/graph/cluster.{type EmergingCluster}
import zeitgeist/graph/fact.{type AtomicFact}
import zeitgeist/predict/scenario.{type Scenario}
import zeitgeist/risk/cascade.{type CascadeImpact}
import zeitgeist/risk/cii.{type CountryRisk}
import zeitgeist/swarm/world.{type World}

pub fn health(status: String) -> Json {
  json.object([
    #("status", json.string(status)),
    #("service", json.string("zeitgeist")),
    #("version", json.string("1.0.0 (Full Spectrum)")),
  ])
}

pub fn scenario_json(s: Scenario) -> Json {
  json.object([
    #("id", json.string(s.id)),
    #("world_id", json.string(s.world_id)),
    #("confidence", json.float(s.confidence)),
    #("horizon_hours", json.int(s.horizon_hours)),
    #("status", json.string(scenario_status_to_string(s.status))),
    #("prediction", prediction_claim_json(s.prediction)),
  ])
}

pub fn scenario_list(scenarios: List(Scenario)) -> Json {
  json.object([
    #("predictions", json.array(scenarios, scenario_json)),
    #("count", json.int(list.length(scenarios))),
  ])
}

fn scenario_status_to_string(status: scenario.ScenarioStatus) -> String {
  case status {
    scenario.Active -> "active"
    scenario.ScenarioConfirmed(_, _) -> "confirmed"
    scenario.ScenarioInvalidated(_) -> "invalidated"
    scenario.Expired -> "expired"
  }
}

fn prediction_claim_json(claim: scenario.PredictionClaim) -> Json {
  case claim {
    scenario.ConflictEscalation(region, from_level, to_level) ->
      json.object([
        #("type", json.string("conflict_escalation")),
        #("region", json.string(region)),
        #("from_level", json.int(from_level)),
        #("to_level", json.int(to_level)),
      ])
    scenario.MarketMove(symbol, direction, magnitude_pct) ->
      json.object([
        #("type", json.string("market_move")),
        #("symbol", json.string(symbol)),
        #("direction", json.string(direction_to_string(direction))),
        #("magnitude_pct", json.float(magnitude_pct)),
      ])
    scenario.InfraDisruption(infra_id, severity) ->
      json.object([
        #("type", json.string("infra_disruption")),
        #("infra_id", json.string(infra_id)),
        #("severity", json.float(severity)),
      ])
    scenario.NarrativeShift(topic, from_sentiment, to_sentiment) ->
      json.object([
        #("type", json.string("narrative_shift")),
        #("topic", json.string(topic)),
        #("from_sentiment", json.float(from_sentiment)),
        #("to_sentiment", json.float(to_sentiment)),
      ])
    scenario.PredictedDiplomaticAction(actor_name, action_type, target) ->
      json.object([
        #("type", json.string("diplomatic_action")),
        #("actor_name", json.string(actor_name)),
        #("action_type", json.string(action_type)),
        #("target", json.string(target)),
      ])
  }
}

fn direction_to_string(d: scenario.Direction) -> String {
  case d {
    scenario.Up -> "up"
    scenario.Down -> "down"
  }
}

pub fn country_risk(risk: CountryRisk) -> Json {
  json.object([
    #("country_code", json.string(risk.country_code)),
    #("cii_score", json.float(risk.cii_score)),
    #("trend", json.string(trend_to_string(risk.trend))),
  ])
}

fn trend_to_string(trend: cii.Trend) -> String {
  case trend {
    cii.Rising -> "rising"
    cii.Stable -> "stable"
    cii.Falling -> "falling"
  }
}

pub fn error_json(message: String) -> Json {
  json.object([#("error", json.string(message))])
}

pub fn event_json(evt: Event) -> Json {
  json.object([
    #("id", json.string(evt.id)),
    #("timestamp", json.int(evt.timestamp)),
    #("stream", json.string(stream_to_string(event.stream_from_kind(evt.kind)))),
    #("confidence", json.float(evt.confidence)),
    #("source", source_to_json(evt.source)),
    #("kind", json.string(event_kind_summary(evt.kind))),
  ])
}

pub fn event_list(events: List(Event)) -> Json {
  json.object([
    #("events", json.array(events, event_json)),
    #("count", json.int(list.length(events))),
  ])
}

pub fn entity_json(ent: Entity) -> Json {
  json.object([
    #("id", json.string(ent.id)),
    #("kind", json.string(entity_kind_to_string(ent.kind))),
    #("name", json.string(ent.name)),
    #("aliases", json.array(ent.aliases, json.string)),
  ])
}

pub fn entity_with_facts(ent: Entity, facts: List(AtomicFact)) -> Json {
  json.object([
    #("id", json.string(ent.id)),
    #("kind", json.string(entity_kind_to_string(ent.kind))),
    #("name", json.string(ent.name)),
    #("aliases", json.array(ent.aliases, json.string)),
    #("facts", json.array(facts, fact_json)),
  ])
}

pub fn fact_json(f: AtomicFact) -> Json {
  json.object([
    #("id", json.string(f.id)),
    #("subject", json.string(f.subject)),
    #("predicate", json.string(relation_to_string(f.predicate))),
    #("object", json.string(f.object)),
    #("confidence", json.float(f.confidence)),
    #("frequency", json.int(f.frequency)),
  ])
}

pub fn stream_to_string(stream: event.EventStream) -> String {
  case stream {
    event.NewsStream -> "news"
    event.MarketStream -> "market"
    event.MilitaryStream -> "military"
    event.InfraStream -> "infra"
    event.SeismicStream -> "seismic"
    event.WeatherStream -> "weather"
    event.SwarmStream -> "swarm"
    event.RiskStream -> "risk"
  }
}

pub fn source_to_json(source: event.Source) -> Json {
  case source {
    event.RealWorld(id) ->
      json.object([
        #("type", json.string("real_world")),
        #("id", json.string(id)),
      ])
    event.Simulation(world_id, agent_id) ->
      json.object([
        #("type", json.string("simulation")),
        #("world_id", json.string(world_id)),
        #("agent_id", json.string(agent_id)),
      ])
    event.RiskEngine(engine) ->
      json.object([
        #("type", json.string("risk_engine")),
        #("engine", json.string(engine)),
      ])
  }
}

pub fn event_kind_summary(kind: event.EventKind) -> String {
  case kind {
    event.NewsArticle(title, _, _) -> "news:" <> title
    event.MarketTick(symbol, _, _) -> "market:" <> symbol
    event.MilitaryTrack(_, callsign, _) -> "military:" <> callsign
    event.InfraStatus(infra_type, status) ->
      "infra:"
      <> infra_type_to_string(infra_type)
      <> ":"
      <> infra_status_to_string(status)
    event.SeismicReading(magnitude, _) -> "seismic:M" <> float_to_str(magnitude)
    event.WeatherAlert(severity, phenomenon) ->
      "weather:" <> alert_severity_to_string(severity) <> ":" <> phenomenon
    event.RiskAlert(risk_type, _, _) ->
      "risk:" <> risk_type_to_string(risk_type)
    event.PredictionEvent(scenario_id, _, _) -> "prediction:" <> scenario_id
    event.CorrelationHit(_, pattern) -> "correlation:" <> pattern
  }
}

pub fn entity_kind_to_string(kind: entity.EntityKind) -> String {
  case kind {
    entity.Person -> "person"
    entity.Government -> "government"
    entity.Military -> "military"
    entity.Corporation -> "corporation"
    entity.Organization -> "organization"
    entity.Location -> "location"
    entity.Infrastructure -> "infrastructure"
    entity.FinancialInstrument -> "financial_instrument"
    entity.MediaOutlet -> "media_outlet"
    entity.Commodity -> "commodity"
  }
}

pub fn relation_to_string(rel: entity.RelationKind) -> String {
  case rel {
    entity.Allied -> "allied"
    entity.Hostile -> "hostile"
    entity.TradePartner -> "trade_partner"
    entity.Sanctions -> "sanctions"
    entity.Owns -> "owns"
    entity.Controls -> "controls"
    entity.LocatedIn -> "located_in"
    entity.SuppliesTo -> "supplies_to"
    entity.MemberOf -> "member_of"
    entity.LeaderOf -> "leader_of"
    entity.Reports -> "reports"
  }
}

fn infra_type_to_string(t: event.InfraType) -> String {
  case t {
    event.SubmarineCable -> "submarine_cable"
    event.Pipeline -> "pipeline"
    event.Port -> "port"
    event.Chokepoint -> "chokepoint"
    event.PowerGrid -> "power_grid"
  }
}

fn infra_status_to_string(s: event.InfraCondition) -> String {
  case s {
    event.Operational -> "operational"
    event.Degraded -> "degraded"
    event.Disrupted -> "disrupted"
    event.Destroyed -> "destroyed"
  }
}

fn alert_severity_to_string(s: event.AlertSeverity) -> String {
  case s {
    event.Low -> "low"
    event.Moderate -> "moderate"
    event.High -> "high"
    event.Extreme -> "extreme"
  }
}

fn risk_type_to_string(r: event.RiskType) -> String {
  case r {
    event.CiiSpike -> "cii_spike"
    event.Convergence -> "convergence"
    event.Cascade -> "cascade"
    event.AnomalyDetected -> "anomaly_detected"
  }
}

pub fn world_json(w: World) -> Json {
  json.object([
    #("id", json.string(w.id)),
    #("name", json.string(w.name)),
    #("tick", json.int(w.tick)),
    #("max_ticks", json.int(w.max_ticks)),
    #("agent_count", json.int(list.length(w.agent_ids))),
    #("state", json.string(world_state_str(w.state))),
    #("world_tension", json.float(w.world_tension)),
  ])
}

pub fn world_list(worlds: List(World)) -> Json {
  json.object([
    #("worlds", json.array(worlds, world_json)),
    #("count", json.int(list.length(worlds))),
  ])
}

fn world_state_str(state: types.WorldState) -> String {
  case state {
    types.Running -> "running"
    types.Paused -> "paused"
    types.Completed -> "completed"
  }
}

fn float_to_str(f: Float) -> String {
  int.to_string(erlang_trunc(f))
}

pub fn cascade_impact_json(impact: CascadeImpact) -> Json {
  json.object([
    #("node_id", json.string(impact.node_id)),
    #("impact", json.float(impact.impact)),
    #("depth", json.int(impact.depth)),
    #("lag_hours", json.float(impact.lag_hours)),
  ])
}

pub fn cascade_impact_list(impacts: List(CascadeImpact)) -> Json {
  json.object([
    #("impacts", json.array(impacts, cascade_impact_json)),
    #("count", json.int(list.length(impacts))),
  ])
}

pub fn emerging_cluster_json(cluster: EmergingCluster) -> Json {
  json.object([
    #("entity_id", json.string(cluster.entity_id)),
    #("new_relations", json.int(cluster.new_relations)),
    #("avg_confidence", json.float(cluster.avg_confidence)),
  ])
}

pub fn emerging_cluster_list(clusters: List(EmergingCluster)) -> Json {
  json.object([
    #("clusters", json.array(clusters, emerging_cluster_json)),
    #("count", json.int(list.length(clusters))),
  ])
}

@external(erlang, "erlang", "trunc")
fn erlang_trunc(f: Float) -> Int
