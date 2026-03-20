import gleam/option.{type Option}
import zeitgeist/core/entity.{type RelationKind}

pub type AtomicFact {
  AtomicFact(
    id: String,
    subject: String,
    predicate: RelationKind,
    object: String,
    observed_at: Int,
    valid_from: Int,
    valid_until: Option(Int),
    confidence: Float,
    source_credibility: Float,
    frequency: Int,
  )
}
