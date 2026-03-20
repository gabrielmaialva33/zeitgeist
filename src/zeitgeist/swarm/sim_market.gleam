import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/list
import gleam/otp/actor

pub type OrderSide {
  Buy
  Sell
}

pub type MarketOrder {
  MarketOrder(
    agent_id: String,
    symbol: String,
    side: OrderSide,
    amount: Float,
    tick: Int,
  )
}

pub type MarketMsg {
  SubmitOrder(order: MarketOrder)
  GetPrice(symbol: String, reply_to: Subject(Float))
  GetOrders(symbol: String, limit: Int, reply_to: Subject(List(MarketOrder)))
  MarketStop
}

type MarketState {
  MarketState(
    world_id: String,
    prices: Dict(String, Float),
    orders: List(MarketOrder),
  )
}

pub fn start(
  world_id: String,
) -> Result(Subject(MarketMsg), actor.StartError) {
  let init_state =
    MarketState(world_id: world_id, prices: dict.new(), orders: [])
  let r =
    actor.new(init_state)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn submit_order(mk: Subject(MarketMsg), order: MarketOrder) -> Nil {
  process.send(mk, SubmitOrder(order))
}

pub fn get_price(mk: Subject(MarketMsg), symbol: String) -> Float {
  process.call(mk, waiting: 5000, sending: fn(reply_to) {
    GetPrice(symbol, reply_to)
  })
}

pub fn get_orders(
  mk: Subject(MarketMsg),
  symbol: String,
  limit: Int,
) -> List(MarketOrder) {
  process.call(mk, waiting: 5000, sending: fn(reply_to) {
    GetOrders(symbol, limit, reply_to)
  })
}

pub fn stop(mk: Subject(MarketMsg)) -> Nil {
  process.send(mk, MarketStop)
}

fn handle_message(
  state: MarketState,
  msg: MarketMsg,
) -> actor.Next(MarketState, MarketMsg) {
  case msg {
    SubmitOrder(order) -> {
      let current_price = case dict.get(state.prices, order.symbol) {
        Ok(p) -> p
        Error(_) -> 100.0
      }
      let new_price = case order.side {
        Buy -> current_price +. order.amount *. 0.001
        Sell ->
          float.max(0.01, current_price -. order.amount *. 0.001)
      }
      let new_prices = dict.insert(state.prices, order.symbol, new_price)
      let new_orders = [order, ..state.orders]
      actor.continue(
        MarketState(..state, prices: new_prices, orders: new_orders),
      )
    }

    GetPrice(symbol, reply_to) -> {
      let price = case dict.get(state.prices, symbol) {
        Ok(p) -> p
        Error(_) -> 100.0
      }
      process.send(reply_to, price)
      actor.continue(state)
    }

    GetOrders(symbol, limit, reply_to) -> {
      let filtered = list.filter(state.orders, fn(o) { o.symbol == symbol })
      let result = list.take(filtered, limit)
      process.send(reply_to, result)
      actor.continue(state)
    }

    MarketStop -> actor.stop()
  }
}
