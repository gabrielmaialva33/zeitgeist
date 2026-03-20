import gleeunit
import gleeunit/should
import zeitgeist/agent/action.{
  CreatePost, Deploy, DiplomaticMessage, DoNothing, IssueSanction, MilitaryAction,
  ObserveAndWait,
}
import zeitgeist/agent/decision.{type DecisionContext, DecisionContext}
import zeitgeist/agent/memory
import zeitgeist/agent/types.{
  type Demographics, Adult, Army, Citizen, Demographics, GovernmentAgent,
  HeadOfState, MilitaryAgent, Primary, Standard, default_personality,
}

pub fn main() {
  gleeunit.main()
}

fn make_ctx(tension: Float) -> DecisionContext {
  DecisionContext(
    tick: 100,
    simulated_hour: 12,
    recent_events_count: 5,
    world_tension: tension,
  )
}

fn make_demographics() -> Demographics {
  Demographics(
    age_range: Adult,
    education: Primary,
    political_lean: 0.5,
    info_diet: [],
  )
}

pub fn hawkish_government_escalates_test() {
  let personality = default_personality()
  let hawk = types.Personality(..personality, hawkishness: 0.9)
  let kind = GovernmentAgent(country: "usa", role: HeadOfState, tier: Standard)
  let mem = memory.new(50)
  let ctx = make_ctx(0.7)

  let action = decision.decide_reactive(kind, hawk, mem, ctx)
  // hawkishness 0.9, tension 0.7 → should NOT be DoNothing
  action |> should.not_equal(DoNothing)
}

pub fn dovish_government_negotiates_test() {
  let personality = default_personality()
  let dove = types.Personality(..personality, hawkishness: 0.1)
  let kind = GovernmentAgent(country: "usa", role: HeadOfState, tier: Standard)
  let mem = memory.new(50)
  let ctx = make_ctx(0.7)

  let action = decision.decide_reactive(kind, dove, mem, ctx)
  // hawkishness 0.1 with tension 0.7 → diplomatic action (DiplomaticMessage)
  case action {
    DiplomaticMessage(_, _, _) -> should.equal(True, True)
    IssueSanction(_, _) -> should.equal(True, True)
    ObserveAndWait -> should.equal(True, True)
    _ -> should.fail()
  }
}

pub fn activation_probability_test() {
  let high_extra =
    types.Personality(..default_personality(), extraversion: 0.9)
  let low_extra = types.Personality(..default_personality(), extraversion: 0.1)

  let peak_prob = decision.activation_probability(high_extra, 14, False)
  let night_prob = decision.activation_probability(low_extra, 3, False)

  let assert True = peak_prob >. 0.3
  let assert True = night_prob <. 0.2
}

pub fn breaking_news_boosts_activation_test() {
  let p = default_personality()

  let with_news = decision.activation_probability(p, 10, True)
  let without_news = decision.activation_probability(p, 10, False)

  let assert True = with_news >. without_news
}

pub fn military_agent_high_tension_deploys_test() {
  let personality =
    types.Personality(..default_personality(), hawkishness: 0.8)
  let kind = MilitaryAgent(country: "usa", branch: Army, rank: 5)
  let mem = memory.new(50)
  let ctx = make_ctx(0.9)

  let action = decision.decide_reactive(kind, personality, mem, ctx)
  action |> should.equal(MilitaryAction(action: Deploy, target: "usa"))
}

pub fn military_agent_low_tension_observes_test() {
  let kind = MilitaryAgent(country: "usa", branch: Army, rank: 3)
  let mem = memory.new(50)
  let ctx = make_ctx(0.3)

  let action = decision.decide_reactive(kind, default_personality(), mem, ctx)
  action |> should.equal(ObserveAndWait)
}

pub fn citizen_extraverted_posts_test() {
  let personality =
    types.Personality(..default_personality(), extraversion: 0.9)
  let kind = Citizen(demographics: make_demographics())
  let mem = memory.new(50)
  let ctx = make_ctx(0.5)

  let action = decision.decide_reactive(kind, personality, mem, ctx)
  case action {
    CreatePost(_, _) -> should.equal(True, True)
    _ -> should.fail()
  }
}

pub fn citizen_introverted_observes_test() {
  let personality =
    types.Personality(..default_personality(), extraversion: 0.1)
  let kind = Citizen(demographics: make_demographics())
  let mem = memory.new(50)
  let ctx = make_ctx(0.5)

  let action = decision.decide_reactive(kind, personality, mem, ctx)
  action |> should.equal(ObserveAndWait)
}

