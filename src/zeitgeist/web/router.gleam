import gleam/bytes_tree
import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import mist.{type Connection}
import zeitgeist/core/event_store
import zeitgeist/graph/store
import zeitgeist/risk/cii_server
import zeitgeist/swarm/world_manager
import zeitgeist/web/json_encode

pub type AppContext {
  AppContext(
    event_store: Subject(event_store.StoreMsg),
    graph: Subject(store.GraphMsg),
    cii: Subject(cii_server.CiiMsg),
    world_manager: Subject(world_manager.ManagerMsg),
  )
}

pub fn make_handler(
  ctx: AppContext,
) -> fn(Request(Connection)) -> Response(mist.ResponseData) {
  fn(req) { handle_request(req, ctx) }
}

fn handle_request(
  req: Request(Connection),
  ctx: AppContext,
) -> Response(mist.ResponseData) {
  case request.path_segments(req) {
    ["api", "health"] -> health_response()
    ["api", "events"] -> events_response(ctx)
    ["api", "risk", "cii", country_code] -> cii_response(ctx, country_code)
    ["api", "graph", "entity", entity_id] -> entity_response(ctx, entity_id)
    ["api", "worlds"] -> worlds_response(ctx)
    ["api", "worlds", world_id] -> world_response(ctx, world_id)
    _ -> not_found_response()
  }
}

fn health_response() -> Response(mist.ResponseData) {
  let body = json_encode.health("ok") |> json.to_string
  response.new(200)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}

fn events_response(ctx: AppContext) -> Response(mist.ResponseData) {
  let events = event_store.recent(ctx.event_store, 50)
  let body = json_encode.event_list(events) |> json.to_string
  response.new(200)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}

fn cii_response(ctx: AppContext, country_code: String) -> Response(mist.ResponseData) {
  let risk = cii_server.get_country(ctx.cii, country_code)
  let body = json_encode.country_risk(risk) |> json.to_string
  response.new(200)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}

fn entity_response(ctx: AppContext, entity_id: String) -> Response(mist.ResponseData) {
  case store.get_entity(ctx.graph, entity_id) {
    Ok(ent) -> {
      let facts = store.get_facts_by_entity(ctx.graph, entity_id)
      let body = json_encode.entity_with_facts(ent, facts) |> json.to_string
      response.new(200)
      |> response.set_header("content-type", "application/json")
      |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
    }
    Error(_) -> not_found_response()
  }
}

fn worlds_response(ctx: AppContext) -> Response(mist.ResponseData) {
  let worlds = world_manager.list_worlds(ctx.world_manager)
  let body = json_encode.world_list(worlds) |> json.to_string
  response.new(200)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}

fn world_response(ctx: AppContext, world_id: String) -> Response(mist.ResponseData) {
  case world_manager.get_world(ctx.world_manager, world_id) {
    Ok(w) -> {
      let body = json_encode.world_json(w) |> json.to_string
      response.new(200)
      |> response.set_header("content-type", "application/json")
      |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
    }
    Error(_) -> not_found_response()
  }
}

fn not_found_response() -> Response(mist.ResponseData) {
  let body = json_encode.error_json("not found") |> json.to_string
  response.new(404)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}
