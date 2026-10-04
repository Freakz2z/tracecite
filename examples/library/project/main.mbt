///|
struct MaintenanceResult {
  references : Int
  before_matches : Bool
  after_matches : Bool
  changes : Array[@tracecite.DocumentSnapshotChange]
} derive(ToJson)

///|
fn maintain_example() -> MaintenanceResult {
  let document = "```toml source=config.toml\ntimeout = 20\n```\n"
  let parsed = @tracecite.parse_document(document)
  let reference = parsed.references[0]
  let before = "timeout = 20"
  let after = "timeout = 30"
  let old : @tracecite.DocumentSnapshotEntry = {
    document: "guide.md",
    source: reference.source,
    kind: reference.kind,
    excerpt: reference.excerpt,
    observed: before,
  }
  let current : @tracecite.DocumentSnapshotEntry = { ..old, observed: after, }
  {
    references: parsed.references.length(),
    before_matches: @tracecite.document_excerpt_matches(
      before,
      reference.excerpt.unwrap(),
      reference.kind,
    ),
    after_matches: @tracecite.document_excerpt_matches(
      after,
      reference.excerpt.unwrap(),
      reference.kind,
    ),
    changes: @tracecite.compare_document_snapshots(
      { version: 1, entries: [old], },
      { version: 1, entries: [current], },
    ),
  }
}

///|
fn main {
  println(@json.to_json(maintain_example()).stringify(indent=2))
}
