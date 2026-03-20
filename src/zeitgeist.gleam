import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor
import mist
import zeitgeist/core/bus
import zeitgeist/core/config
import zeitgeist/core/event
import zeitgeist/core/event_store
import zeitgeist/graph/store
import zeitgeist/llm/pool
import zeitgeist/llm/types
import zeitgeist/predict/feedback
import zeitgeist/risk/cii_server
import zeitgeist/signal/conflict_feed
import zeitgeist/signal/rss
import zeitgeist/signal/seismic
import zeitgeist/signal/source
import zeitgeist/swarm/registry
import zeitgeist/swarm/world_manager
import zeitgeist/web/router

pub fn main() {
  io.println("  ⚡ Zeitgeist v0.4.0 (P3 — LLM Integration)")
  io.println("  Real-time global intelligence platform — P3 LLM Integration")
  io.println("")

  let cfg = config.load()
  io.println("  [config] loaded (port " <> int.to_string(cfg.http_port) <> ")")

  let assert Ok(bus_subject) = bus.start()
  io.println("  [bus] event bus started")

  let assert Ok(event_store_subject) = event_store.start("zeitgeist", 10_000)
  io.println("  [store] event store started")

  let assert Ok(graph_subject) = store.start("zeitgeist")
  io.println("  [graph] knowledge graph started")

  let assert Ok(cii_subject) = cii_server.start(bus_subject)
  io.println("  [cii] CII server started")

  let assert Ok(registry_subject) = registry.start("zeitgeist")
  io.println("  [registry] agent registry started")

  let assert Ok(world_manager_subject) = world_manager.start(registry_subject)
  io.println("  [world_manager] world manager started")

  let llm_cfg =
    pool.PoolConfig(
      default_provider: types.MockProvider,
      fallback_provider: types.MockProvider,
      max_concurrent: 4,
    )
  let assert Ok(llm_pool_subject) = pool.start(llm_cfg)
  io.println("  [llm_pool] LLM pool started (mock provider)")

  let assert Ok(feedback_subject) = feedback.start()
  io.println("  [feedback] prediction feedback server started")

  // Subscribe event store to bus (all streams)
  subscribe_store_to_bus(bus_subject, event_store_subject)
  io.println("  [bridge] event store subscribed to bus")

  // RSS sources
  let assert Ok(_reuters) =
    rss.start(
      source.RssFeed(
        id: "reuters",
        url: "https://feeds.reuters.com/reuters/worldNews",
        poll_interval_ms: 60_000,
      ),
      bus_subject,
    )
  io.println("  [signal] reuters RSS source started")

  let assert Ok(_ap) =
    rss.start(
      source.RssFeed(
        id: "ap_news",
        url: "https://rsshub.app/apnews/topics/apf-topnews",
        poll_interval_ms: 60_000,
      ),
      bus_subject,
    )
  io.println("  [signal] ap_news RSS source started")

  // Seismic source (USGS stub)
  let assert Ok(_usgs) =
    seismic.start(
      source.SeismicSource(
        id: "usgs",
        url: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/significant_hour.geojson",
        poll_interval_ms: 120_000,
      ),
      bus_subject,
    )
  io.println("  [signal] USGS seismic source started")

  // Conflict source (ACLED stub)
  let assert Ok(_acled) =
    conflict_feed.start(
      source.ConflictSource(
        id: "acled",
        url: "https://api.acleddata.com/acled/read",
        poll_interval_ms: 300_000,
      ),
      bus_subject,
    )
  io.println("  [signal] ACLED conflict source started")

  let ctx =
    router.AppContext(
      event_store: event_store_subject,
      graph: graph_subject,
      cii: cii_subject,
      world_manager: world_manager_subject,
      feedback: feedback_subject,
      llm_pool: llm_pool_subject,
    )

  let assert Ok(_) =
    mist.new(router.make_handler(ctx))
    |> mist.port(cfg.http_port)
    |> mist.start
  io.println(
    "  [web] listening on http://localhost:" <> int.to_string(cfg.http_port),
  )

  io.println("")
  io.println("  Zeitgeist is running. Ctrl+C to stop.")

  process.sleep_forever()
}

fn subscribe_store_to_bus(
  bus_subj: process.Subject(bus.BusMsg),
  store: process.Subject(event_store.StoreMsg),
) -> Nil {
  let r =
    actor.new_with_initialiser(5000, fn(self) {
      // Subscribe this actor's subject to all relevant streams
      process.send(bus_subj, bus.Subscribe(event.NewsStream, self))
      process.send(bus_subj, bus.Subscribe(event.SeismicStream, self))
      process.send(bus_subj, bus.Subscribe(event.MarketStream, self))
      process.send(bus_subj, bus.Subscribe(event.MilitaryStream, self))
      process.send(bus_subj, bus.Subscribe(event.InfraStream, self))
      process.send(bus_subj, bus.Subscribe(event.WeatherStream, self))
      process.send(bus_subj, bus.Subscribe(event.RiskStream, self))
      store
      |> actor.initialised
      |> actor.selecting(process.new_selector() |> process.select(self))
      |> actor.returning(self)
      |> Ok
    })
    |> actor.on_message(fn(st, msg: event.Event) {
      event_store.push(st, msg)
      actor.continue(st)
    })
    |> actor.start
  let _ = r
  Nil
}
