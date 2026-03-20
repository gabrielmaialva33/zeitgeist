import gleam/erlang/process
import gleam/int
import gleam/io
import mist
import zeitgeist/core/bus
import zeitgeist/core/config
import zeitgeist/graph/store
import zeitgeist/signal/rss
import zeitgeist/signal/source
import zeitgeist/web/router

pub fn main() {
  io.println("  ⚡ Zeitgeist v0.1.0")
  io.println("  Real-time global intelligence platform")
  io.println("")

  let cfg = config.load()
  io.println("  [config] loaded (port " <> int.to_string(cfg.http_port) <> ")")

  let assert Ok(bus_subject) = bus.start()
  io.println("  [bus] event bus started")

  let assert Ok(_graph) = store.start("zeitgeist")
  io.println("  [graph] knowledge graph started")

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

  let assert Ok(_) =
    mist.new(router.handle_request)
    |> mist.port(cfg.http_port)
    |> mist.start
  io.println(
    "  [web] listening on http://localhost:" <> int.to_string(cfg.http_port),
  )

  io.println("")
  io.println("  Zeitgeist is running. Ctrl+C to stop.")

  process.sleep_forever()
}
