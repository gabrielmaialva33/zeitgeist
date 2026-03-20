import gleeunit
import gleeunit/should
import zeitgeist/swarm/sim_market

pub fn main() {
  gleeunit.main()
}

pub fn buy_increases_price_test() {
  let assert Ok(mk) = sim_market.start("world1")

  let order =
    sim_market.MarketOrder(
      agent_id: "trader1",
      symbol: "AAPL",
      side: sim_market.Buy,
      amount: 100.0,
      tick: 1,
    )

  sim_market.submit_order(mk, order)

  let price = sim_market.get_price(mk, "AAPL")
  // 100.0 + 100.0 * 0.001 = 100.1
  should.be_true(price >. 100.0)

  sim_market.stop(mk)
}

pub fn sell_decreases_price_test() {
  let assert Ok(mk) = sim_market.start("world2")

  // First set a price by buying
  sim_market.submit_order(
    mk,
    sim_market.MarketOrder(
      agent_id: "trader1",
      symbol: "TSLA",
      side: sim_market.Buy,
      amount: 1.0,
      tick: 1,
    ),
  )

  let price_after_buy = sim_market.get_price(mk, "TSLA")

  sim_market.submit_order(
    mk,
    sim_market.MarketOrder(
      agent_id: "trader2",
      symbol: "TSLA",
      side: sim_market.Sell,
      amount: 50.0,
      tick: 2,
    ),
  )

  let price_after_sell = sim_market.get_price(mk, "TSLA")
  should.be_true(price_after_sell <. price_after_buy)

  sim_market.stop(mk)
}

pub fn default_price_is_100_test() {
  let assert Ok(mk) = sim_market.start("world3")

  let price = sim_market.get_price(mk, "UNKNOWN")
  should.equal(100.0, price)

  sim_market.stop(mk)
}

pub fn order_log_tracks_all_orders_test() {
  let assert Ok(mk) = sim_market.start("world4")

  sim_market.submit_order(
    mk,
    sim_market.MarketOrder(
      agent_id: "a",
      symbol: "BTC",
      side: sim_market.Buy,
      amount: 10.0,
      tick: 1,
    ),
  )
  sim_market.submit_order(
    mk,
    sim_market.MarketOrder(
      agent_id: "b",
      symbol: "BTC",
      side: sim_market.Sell,
      amount: 5.0,
      tick: 2,
    ),
  )
  sim_market.submit_order(
    mk,
    sim_market.MarketOrder(
      agent_id: "c",
      symbol: "ETH",
      side: sim_market.Buy,
      amount: 20.0,
      tick: 3,
    ),
  )

  let btc_orders = sim_market.get_orders(mk, "BTC", 10)
  should.equal(2, list_length(btc_orders))

  let eth_orders = sim_market.get_orders(mk, "ETH", 10)
  should.equal(1, list_length(eth_orders))

  sim_market.stop(mk)
}

pub fn price_floor_prevents_negative_test() {
  let assert Ok(mk) = sim_market.start("world5")

  // Massive sell should not go below 0.01
  sim_market.submit_order(
    mk,
    sim_market.MarketOrder(
      agent_id: "bear",
      symbol: "DOGE",
      side: sim_market.Sell,
      amount: 1_000_000.0,
      tick: 1,
    ),
  )

  let price = sim_market.get_price(mk, "DOGE")
  should.be_true(price >=. 0.01)

  sim_market.stop(mk)
}

fn list_length(lst: List(a)) -> Int {
  case lst {
    [] -> 0
    [_, ..rest] -> 1 + list_length(rest)
  }
}
