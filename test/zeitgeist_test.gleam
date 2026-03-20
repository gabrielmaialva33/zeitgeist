import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option.{None}
import gleeunit
import gleeunit/should
import zeitgeist/agent/types
import zeitgeist/core/bus
import zeitgeist/core/entity
import zeitgeist/core/event
import zeitgeist/core/event_store
import zeitgeist/graph/cluster
import zeitgeist/graph/fact.{AtomicFact}
import zeitgeist/graph/store
import zeitgeist/llm/pool
import zeitgeist/llm/types as llm_types
import zeitgeist/predict/feedback
import zeitgeist/predict/scenario
import zeitgeist/risk/alert_fusion
import zeitgeist/risk/cascade
import zeitgeist/risk/cii
import zeitgeist/risk/cii_server
import zeitgeist/risk/correlation
import zeitgeist/risk/keyword_spike
import zeitgeist/risk/theater
import zeitgeist/agent/action
import zeitgeist/swarm/kg_feedback
import zeitgeist/swarm/registry
import zeitgeist/swarm/world_manager

pub fn main() {
  gleeunit.main()
}

pub fn integration_event_flow_test() {
  let assert Ok(bus_subject) = bus.start()
  let assert Ok(graph_subject) = store.start("integ_" <> unique())

  // Subscribe to news
  let receiver = process.new_subject()
  process.send(bus_subject, bus.Subscribe(event.NewsStream, receiver))

  // Publish a news event
  let evt =
    event.Event(
      id: "test_001",
      timestamp: 1_774_017_000_000,
      kind: event.NewsArticle(
        title: "Conflict escalates in region X",
        summary: "Multiple incidents reported",
        category: event.Conflict,
      ),
      source: event.RealWorld("test"),
      location: None,
      entities: [],
      confidence: 0.9,
      raw: None,
    )
  process.send(bus_subject, bus.Publish(evt))

  // Verify subscriber received it
  let assert Ok(received) = process.receive(receiver, 1000)
  received.id |> should.equal("test_001")

  // Store entity + fact
  store.upsert_entity(
    graph_subject,
    entity.Entity(
      id: "region_x",
      kind: entity.Location,
      name: "Region X",
      aliases: [],
      attributes: dict.new(),
    ),
  )

  let fact =
    AtomicFact(
      id: "fact_001",
      subject: "region_x",
      predicate: entity.Hostile,
      object: "faction_a",
      observed_at: 1_774_017_000_000,
      valid_from: 1_774_017_000_000,
      valid_until: None,
      confidence: 0.9,
      source_credibility: 0.95,
      frequency: 1,
    )
  store.upsert_fact(graph_subject, fact)

  // Verify stored
  store.entity_count(graph_subject) |> should.equal(1)
  store.fact_count(graph_subject) |> should.equal(1)

  // CII scoring
  let risk = cii.new("XX") |> cii.update_score(80.0)
  let assert True = risk.cii_score >. 0.0

  store.stop(graph_subject)
}

pub fn p1_event_store_integration_test() {
  let assert Ok(b) = bus.start()
  let assert Ok(es) = event_store.start("p1_integ_" <> unique(), 1000)
  let assert Ok(cii_srv) = cii_server.start(b)

  // Push events directly into event store (bus bridge tested separately)
  let news_evt =
    event.Event(
      id: "p1_news_001",
      timestamp: 1_774_100_000_000,
      kind: event.NewsArticle(
        title: "P1 test event",
        summary: "integration test",
        category: event.General,
      ),
      source: event.RealWorld("test"),
      location: None,
      entities: [],
      confidence: 0.9,
      raw: None,
    )
  event_store.push(es, news_evt)

  let seismic_evt =
    event.Event(
      id: "p1_seismic_001",
      timestamp: 1_774_100_001_000,
      kind: event.SeismicReading(magnitude: 5.2, depth_km: 15.0),
      source: event.RealWorld("usgs"),
      location: None,
      entities: [],
      confidence: 0.95,
      raw: None,
    )
  event_store.push(es, seismic_evt)

  // Verify events in store
  let size = event_store.get_size(es)
  size |> should.equal(2)

  let recent = event_store.recent(es, 10)
  let found_news =
    list_any(recent, fn(e: event.Event) { e.id == "p1_news_001" })
  let assert True = found_news

  // Verify by stream
  let seismic_events = event_store.by_stream(es, event.SeismicStream, 10)
  list.length(seismic_events) |> should.equal(1)

  // Update CII, verify score > 0
  cii_server.update_country(cii_srv, "SY", 75.0)
  process.sleep(50)
  let risk = cii_server.get_country(cii_srv, "SY")
  let assert True = risk.cii_score >. 0.0

  event_store.stop(es)
  cii_server.stop(cii_srv)
}

fn list_any(lst: List(a), pred: fn(a) -> Bool) -> Bool {
  case lst {
    [] -> False
    [head, ..tail] ->
      case pred(head) {
        True -> True
        False -> list_any(tail, pred)
      }
  }
}

pub fn p2_prediction_test() {
  let s =
    scenario.new(
      "s1",
      "w1",
      scenario.ConflictEscalation(region: "ME", from_level: 2, to_level: 4),
      0.7,
      48,
    )
  s.status |> should.equal(scenario.Active)
  let expired =
    scenario.check_expiry(scenario.Scenario(..s, created_at: 0), 200_000_000)
  expired.status |> should.equal(scenario.Expired)
}

pub fn p2_simulation_smoke_test() {
  let assert Ok(reg) = registry.start("smoke_" <> unique())
  let assert Ok(mgr) = world_manager.start(reg)

  let agent_specs = [
    world_manager.AgentSpec(
      id: "agent_1",
      kind: types.JournalistAgent(outlet: "smoke_press", reach: 100),
      personality: types.default_personality(),
    ),
    world_manager.AgentSpec(
      id: "agent_2",
      kind: types.TraderAgent(firm: "smoke_firm", style: types.Aggressive),
      personality: types.default_personality(),
    ),
    world_manager.AgentSpec(
      id: "agent_3",
      kind: types.GovernmentAgent(
        country: "XX",
        role: types.Ambassador,
        tier: types.Reactive,
      ),
      personality: types.default_personality(),
    ),
  ]

  let cfg =
    world_manager.WorldCreateConfig(
      name: "smoke_world",
      max_ticks: 5,
      tick_interval_ms: 50,
      agents: agent_specs,
      world_tension: 0.3,
    )

  let assert Ok(w) = world_manager.create_world(mgr, cfg)
  w.name |> should.equal("smoke_world")
  list.length(w.agent_ids) |> should.equal(3)

  // Wait for some ticks
  process.sleep(200)

  // Verify world is tracked
  let worlds = world_manager.list_worlds(mgr)
  list.length(worlds) |> should.equal(1)

  // Verify agents registered
  let registered = registry.list_world_agents(reg, w.id)
  let assert True = list.length(registered) >= 1

  world_manager.stop(mgr)
  registry.stop(reg)
}

pub fn p3_integration_test() {
  // 1. Start LLM pool with mock provider
  let llm_cfg =
    pool.PoolConfig(
      default_provider: llm_types.MockProvider,
      fallback_provider: llm_types.MockProvider,
      max_concurrent: 2,
    )
  let assert Ok(llm_pool) = pool.start(llm_cfg)

  // 2. Mock LLM request via pool
  let req =
    llm_types.new_request(
      "predict the diplomatic outcome",
      llm_types.MockProvider,
    )
  let assert Ok(resp) = pool.complete(llm_pool, req)
  should.be_true(resp.content != "")
  should.equal(resp.provider, "mock")

  // 3. Start feedback server, create a prediction
  let assert Ok(fb) = feedback.start()
  let s =
    scenario.new(
      "p3_s1",
      "w_p3",
      scenario.ConflictEscalation(region: "ME", from_level: 2, to_level: 4),
      0.75,
      48,
    )
  feedback.add_prediction(fb, s)
  process.sleep(20)

  let active = feedback.list_active(fb)
  list.length(active) |> should.equal(1)

  // 4. Validate event confirms prediction
  let evt =
    event.Event(
      ..event.new(
        "p3_e1",
        event.NewsArticle(
          title: "Conflict escalation in ME confirmed",
          summary: "tensions peak",
          category: event.Conflict,
        ),
      ),
      timestamp: 5000,
    )
  feedback.check_event(fb, evt)
  process.sleep(50)

  let stats = feedback.get_stats(fb)
  stats.confirmed |> should.equal(1)

  let still_active = feedback.list_active(fb)
  list.length(still_active) |> should.equal(0)

  // Verify pool stats
  let pool_stats = pool.get_stats(llm_pool)
  pool_stats.total_requests |> should.equal(1)
  pool_stats.successes |> should.equal(1)

  feedback.stop(fb)
  pool.stop(llm_pool)
}

pub fn p4_full_spectrum_integration_test() {
  // --- Cascade propagation ---
  let graph =
    cascade.new_graph()
    |> cascade.add_node(cascade.InfraNode(
      id: "cable_atlantic",
      kind: cascade.SubmarineCableNode,
      capacity: 1.0,
      redundancy: 0.2,
      dependents: [cascade.Dependency(target: "port_rotterdam", weight: 0.7, lag_hours: 2.0)],
    ))
    |> cascade.add_node(cascade.InfraNode(
      id: "port_rotterdam",
      kind: cascade.PortNode,
      capacity: 1.0,
      redundancy: 0.3,
      dependents: [cascade.Dependency(target: "trade_route_eu", weight: 0.6, lag_hours: 4.0)],
    ))
    |> cascade.add_node(cascade.InfraNode(
      id: "trade_route_eu",
      kind: cascade.TradeRoute,
      capacity: 1.0,
      redundancy: 0.1,
      dependents: [],
    ))

  let impacts = cascade.propagate(graph, "cable_atlantic", 0.9, 3)
  // Should have at least 3 impacts (trigger + 2 propagations)
  should.be_true(list.length(impacts) >= 3)

  // Verify depth-1 impact exists and is < trigger disruption (attenuated)
  let depth1 = cascade.impact_at_depth(impacts, 1)
  should.be_true(list.length(depth1) >= 1)
  let assert [first_d1, ..] = depth1
  should.be_true(first_d1.impact <. 0.9)

  // --- Emerging clusters ---
  let now = 1_774_100_000_000
  let window = 3_600_000
  let facts = [
    AtomicFact(
      id: "f1",
      subject: "iran",
      predicate: entity.Hostile,
      object: "usa",
      observed_at: now - 100_000,
      valid_from: now - 100_000,
      valid_until: None,
      confidence: 0.9,
      source_credibility: 0.9,
      frequency: 1,
    ),
    AtomicFact(
      id: "f2",
      subject: "iran",
      predicate: entity.Allied,
      object: "russia",
      observed_at: now - 200_000,
      valid_from: now - 200_000,
      valid_until: None,
      confidence: 0.8,
      source_credibility: 0.85,
      frequency: 1,
    ),
    AtomicFact(
      id: "f3",
      subject: "iran",
      predicate: entity.Controls,
      object: "strait_of_hormuz",
      observed_at: now - 300_000,
      valid_from: now - 300_000,
      valid_until: None,
      confidence: 0.85,
      source_credibility: 0.9,
      frequency: 1,
    ),
    AtomicFact(
      id: "f4",
      subject: "usa",
      predicate: entity.MemberOf,
      object: "nato",
      observed_at: now - 50_000,
      valid_from: now - 50_000,
      valid_until: None,
      confidence: 0.95,
      source_credibility: 0.95,
      frequency: 1,
    ),
  ]

  let clusters = cluster.detect(facts, now, window, 2)
  // Iran has 3 facts in window, should appear as emerging cluster
  let iran_cluster =
    list.filter(clusters, fn(c: cluster.EmergingCluster) {
      c.entity_id == "iran"
    })
  should.be_true(list.length(iran_cluster) >= 1)
  let assert [ic, ..] = iran_cluster
  should.be_true(ic.new_relations >= 3)
  should.be_true(ic.avg_confidence >. 0.0)

  // --- Correlation patterns ---
  // 1. Cascade trigger: high disruption + market drop
  let cascade_hit =
    correlation.check_cascade_trigger(0.85, -3.2, 0.5)
  should.equal(cascade_hit, True)

  // 2. Entity frequency spike: Iran mentions tripled
  let freq_spike =
    correlation.check_entity_frequency_spike(90, 20, 3.0)
  should.equal(freq_spike, True)

  // 3. Multi-region convergence: 5 regions affected
  let convergence = correlation.check_multi_region_convergence(5, 3)
  should.equal(convergence, True)

  // All assertions pass → full spectrum integration verified
  Nil
}

pub fn p5_integration_test() {
  // --- Theater posture: iran_gulf + 12 activity = Elevated ---
  let t = theater.new("iran_gulf") |> theater.add_activity(12)
  t.posture |> should.equal(theater.Elevated)
  let assert True = t.activity_count == 12

  // --- Alert fusion convergence score ---
  let sig_a =
    alert_fusion.new_signal(
      "sig_001",
      "military",
      "IR",
      None,
      0.85,
      1_000_000_000,
    )
  let sig_b =
    alert_fusion.new_signal(
      "sig_002",
      "intelligence",
      "IR",
      None,
      0.9,
      1_000_100_000,
    )

  let result = alert_fusion.try_merge(sig_a, sig_b, 500.0, 3_600_000)
  result |> should.be_ok
  let assert Ok(fused) = result
  let assert True = fused.convergence_score >. 0.0

  // --- Keyword extraction ---
  let keywords =
    keyword_spike.extract_keywords("missile strike hit the port forces conflict")
  list.contains(keywords, "missile") |> should.equal(True)
  list.contains(keywords, "strike") |> should.equal(True)
  list.contains(keywords, "conflict") |> should.equal(True)
  // stop word "the" filtered
  list.contains(keywords, "the") |> should.equal(False)

  // --- KG feedback: action_to_fact ---
  let fact_result =
    kg_feedback.action_to_fact(
      "agent_ir_001",
      "world_test",
      action.DiplomaticMessage(
        to: "agent_us_001",
        content: "We seek dialogue",
        public: True,
      ),
      1_000_000_000,
    )
  fact_result |> should.be_ok
  let assert Ok(fact) = fact_result
  fact.subject |> should.equal("agent_ir_001")
  fact.predicate |> should.equal(entity.Allied)
  fact.object |> should.equal("agent_us_001")

  Nil
}

@external(erlang, "erlang", "unique_integer")
fn unique_int() -> Int

fn unique() -> String {
  int_to_string(unique_int())
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string(i: Int) -> String
