import zeitgeist/agent/action.{
  type AgentActionType, CreatePost, Deploy, DiplomaticMessage, IssueSanction,
  MarketBuy, MarketSell, MilitaryAction, ObserveAndWait,
}
import zeitgeist/agent/memory.{type AgentMemory}
import zeitgeist/agent/types.{
  type AgentKind, type Personality, Citizen, CorporationAgent, GovernmentAgent,
  InfluencerAgent, JournalistAgent, MilitaryAgent, TraderAgent,
}

pub type DecisionContext {
  DecisionContext(
    tick: Int,
    simulated_hour: Int,
    recent_events_count: Int,
    world_tension: Float,
  )
}

// Hour activity curve: returns a base activity level [0.0, 1.0]
fn hour_curve(hour: Int) -> Float {
  case hour {
    h if h >= 0 && h <= 5 -> 0.1
    h if h >= 6 && h <= 7 -> 0.2
    h if h >= 8 && h <= 12 -> 0.4
    h if h >= 13 && h <= 17 -> 0.5
    h if h >= 18 && h <= 21 -> 0.5
    h if h >= 22 && h <= 23 -> 0.25
    _ -> 0.1
  }
}

// Activation probability: how likely is this agent to act this tick
pub fn activation_probability(
  personality: Personality,
  hour: Int,
  breaking_news: Bool,
) -> Float {
  let curve = hour_curve(hour)
  let base = curve *. { 0.5 +. personality.extraversion *. 0.5 }
  let boost = case breaking_news {
    True -> 0.3
    False -> 0.0
  }
  let total = base +. boost
  case total >. 1.0 {
    True -> 1.0
    False -> total
  }
}

// Reactive decision — rule-based
pub fn decide_reactive(
  kind: AgentKind,
  personality: Personality,
  _mem: AgentMemory,
  ctx: DecisionContext,
) -> AgentActionType {
  case kind {
    GovernmentAgent(country: country, ..) ->
      decide_government(country, personality, ctx)

    MilitaryAgent(country: country, ..) ->
      decide_military(country, personality, ctx)

    TraderAgent(..) -> decide_trader(personality, ctx)

    Citizen(..) -> decide_citizen(personality)

    CorporationAgent(..) -> ObserveAndWait
    JournalistAgent(..) -> ObserveAndWait
    InfluencerAgent(..) -> ObserveAndWait
  }
}

fn decide_government(
  country: String,
  personality: Personality,
  ctx: DecisionContext,
) -> AgentActionType {
  let hawk = personality.hawkishness
  let tension = ctx.world_tension

  case hawk >=. 0.7 && tension >=. 0.6 {
    True -> MilitaryAction(action: Deploy, target: country)
    False ->
      case hawk >=. 0.5 && tension >=. 0.5 {
        True -> IssueSanction(target_country: "adversary", severity: hawk)
        False ->
          case tension >=. 0.4 {
            True ->
              DiplomaticMessage(
                to: "adversary",
                content: "We seek dialogue.",
                public: True,
              )
            False -> ObserveAndWait
          }
      }
  }
}

fn decide_military(
  country: String,
  personality: Personality,
  ctx: DecisionContext,
) -> AgentActionType {
  case ctx.world_tension >. 0.8 && personality.hawkishness >. 0.6 {
    True -> MilitaryAction(action: Deploy, target: country)
    False -> ObserveAndWait
  }
}

fn decide_trader(
  personality: Personality,
  ctx: DecisionContext,
) -> AgentActionType {
  case ctx.world_tension >. 0.6 && personality.risk_appetite >. 0.7 {
    True -> MarketBuy(symbol: "GOLD", amount: 100.0)
    False ->
      case ctx.world_tension >. 0.6 {
        True -> MarketSell(symbol: "STOCKS", amount: 100.0)
        False -> ObserveAndWait
      }
  }
}

fn decide_citizen(personality: Personality) -> AgentActionType {
  case personality.extraversion >. 0.6 {
    True -> CreatePost(platform: "social", content: "My thoughts on events...")
    False -> ObserveAndWait
  }
}
