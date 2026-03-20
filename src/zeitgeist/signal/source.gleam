pub type SourceConfig {
  RssFeed(id: String, url: String, poll_interval_ms: Int)
}

pub type SourceHealth {
  SourceHealth(
    source_id: String,
    status: SourceStatus,
    events_total: Int,
    last_event_at: Int,
    error_count: Int,
  )
}

pub type SourceStatus {
  Active
  SourceDegraded(reason: String)
  Down(since: Int)
}
