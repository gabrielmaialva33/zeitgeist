// Agent action types

pub type MilitaryActionKind {
  Mobilize
  Deploy
  Strike
  Withdraw
}

pub type AgentActionType {
  DiplomaticMessage(to: String, content: String, public: Bool)
  IssueSanction(target_country: String, severity: Float)
  FormAlliance(target_country: String)
  MilitaryAction(action: MilitaryActionKind, target: String)
  CreatePost(platform: String, content: String)
  MarketBuy(symbol: String, amount: Float)
  MarketSell(symbol: String, amount: Float)
  DoNothing
  ObserveAndWait
}
