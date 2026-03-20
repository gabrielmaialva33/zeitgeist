import gleam/dict.{type Dict}

pub type Entity {
  Entity(
    id: String,
    kind: EntityKind,
    name: String,
    aliases: List(String),
    attributes: Dict(String, String),
  )
}

pub type EntityRef {
  EntityRef(id: String, kind: EntityKind, name: String)
}

pub type EntityKind {
  Person
  Government
  Military
  Corporation
  Organization
  Location
  Infrastructure
  FinancialInstrument
  MediaOutlet
  Commodity
}

pub type RelationKind {
  Allied
  Hostile
  TradePartner
  Sanctions
  Owns
  Controls
  LocatedIn
  SuppliesTo
  MemberOf
  LeaderOf
  Reports
}
