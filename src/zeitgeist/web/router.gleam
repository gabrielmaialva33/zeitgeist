import gleam/bytes_tree
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import mist.{type Connection}
import zeitgeist/web/json_encode

pub fn handle_request(req: Request(Connection)) -> Response(mist.ResponseData) {
  case request.path_segments(req) {
    ["api", "health"] -> health_response()
    _ -> not_found_response()
  }
}

fn health_response() -> Response(mist.ResponseData) {
  let body = json_encode.health("ok") |> json.to_string
  response.new(200)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}

fn not_found_response() -> Response(mist.ResponseData) {
  let body = json_encode.error_json("not found") |> json.to_string
  response.new(404)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}
