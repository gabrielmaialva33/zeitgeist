import gleam/option.{type Option, None}
import zeitgeist/core/entity.{type EntityRef}
import zeitgeist/core/geo.{type GeoPoint}

pub type Event {
  Event(
    id: String,
    timestamp: Int,
    kind: EventKind,
    source: Source,
    location: Option(GeoPoint),
    entities: List(EntityRef),
    confidence: Float,
    raw: Option(String),
  )
}

pub type Source {
  RealWorld(source_id: String)
  Simulation(world_id: String, agent_id: String)
  RiskEngine(engine: String)
}

pub type EventKind {
  NewsArticle(title: String, summary: String, category: NewsCategory)
  MarketTick(symbol: String, price: Float, change_pct: Float)
  MilitaryTrack(track_type: TrackType, callsign: String, heading: Float)
  InfraStatus(infra_type: InfraType, status: InfraCondition)
  SeismicReading(magnitude: Float, depth_km: Float)
  WeatherAlert(severity: AlertSeverity, phenomenon: String)
  RiskAlert(risk_type: RiskType, score: Float, details: String)
  PredictionEvent(scenario_id: String, probability: Float, horizon_hours: Int)
  CorrelationHit(streams: List(EventStream), pattern: String)
}

pub type EventStream {
  NewsStream
  MarketStream
  MilitaryStream
  InfraStream
  SeismicStream
  WeatherStream
  SwarmStream
  RiskStream
}

pub type NewsCategory {
  Politics
  Conflict
  Economy
  Technology
  Climate
  Health
  General
}

pub type TrackType {
  Aircraft
  Vessel
}

pub type InfraType {
  SubmarineCable
  Pipeline
  Port
  Chokepoint
  PowerGrid
}

pub type InfraCondition {
  Operational
  Degraded
  Disrupted
  Destroyed
}

pub type AlertSeverity {
  Low
  Moderate
  High
  Extreme
}

pub type RiskType {
  CiiSpike
  Convergence
  Cascade
  AnomalyDetected
}

pub fn new(id: String, kind: EventKind) -> Event {
  Event(
    id: id,
    timestamp: 0,
    kind: kind,
    source: RealWorld("unknown"),
    location: None,
    entities: [],
    confidence: 0.5,
    raw: None,
  )
}

pub fn stream_from_kind(kind: EventKind) -> EventStream {
  case kind {
    NewsArticle(..) -> NewsStream
    MarketTick(..) -> MarketStream
    MilitaryTrack(..) -> MilitaryStream
    InfraStatus(..) -> InfraStream
    SeismicReading(..) -> SeismicStream
    WeatherAlert(..) -> WeatherStream
    RiskAlert(..) -> RiskStream
    PredictionEvent(..) -> RiskStream
    CorrelationHit(..) -> RiskStream
  }
}
