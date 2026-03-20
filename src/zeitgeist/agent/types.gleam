import gleam/dict.{type Dict}

// ---------------------------------------------------------------------------
// Demographics
// ---------------------------------------------------------------------------

pub type AgeRange {
  Youth
  Adult
  Senior
}

pub type EducationLevel {
  Primary
  Secondary
  Tertiary
  PostGraduate
}

pub type Demographics {
  Demographics(
    age_range: AgeRange,
    education: EducationLevel,
    political_lean: Float,
    info_diet: List(String),
  )
}

// ---------------------------------------------------------------------------
// Gov / Military / Market sub-types
// ---------------------------------------------------------------------------

pub type GovRole {
  HeadOfState
  ForeignMinister
  DefenseMinister
  Ambassador
}

pub type MilitaryBranch {
  Army
  Navy
  AirForce
  Intelligence
}

pub type MarketCap {
  SmallCap
  MidCap
  LargeCap
}

pub type TradingStyle {
  Conservative
  Moderate
  Aggressive
}

pub type AgentTier {
  Elite
  Standard
  Reactive
}

// ---------------------------------------------------------------------------
// Personality — Big Five + SWA weights
// ---------------------------------------------------------------------------

pub type Personality {
  Personality(
    openness: Float,
    conscientiousness: Float,
    extraversion: Float,
    agreeableness: Float,
    neuroticism: Float,
    conformity: Float,
    contrarianism: Float,
    risk_appetite: Float,
    hawkishness: Float,
    influence_radius: Float,
    trust_network: Dict(String, Float),
  )
}

pub fn default_personality() -> Personality {
  Personality(
    openness: 0.5,
    conscientiousness: 0.5,
    extraversion: 0.5,
    agreeableness: 0.5,
    neuroticism: 0.5,
    conformity: 0.5,
    contrarianism: 0.5,
    risk_appetite: 0.5,
    hawkishness: 0.5,
    influence_radius: 0.5,
    trust_network: dict.new(),
  )
}

// ---------------------------------------------------------------------------
// AgentKind — 7 variants (prefixed to avoid collision with EntityKind)
// ---------------------------------------------------------------------------

pub type AgentKind {
  Citizen(demographics: Demographics)
  GovernmentAgent(country: String, role: GovRole, tier: AgentTier)
  MilitaryAgent(country: String, branch: MilitaryBranch, rank: Int)
  CorporationAgent(company: String, sector: String, market_cap: MarketCap)
  TraderAgent(firm: String, style: TradingStyle)
  JournalistAgent(outlet: String, reach: Int)
  InfluencerAgent(platform: String, followers: Int)
}

// ---------------------------------------------------------------------------
// WorldState
// ---------------------------------------------------------------------------

pub type WorldState {
  Running
  Paused
  Completed
}
