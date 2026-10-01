///|
pub(all) struct DocumentSnapshotChange {
  document : String
  source : String
  kind : String
  excerpt : String?
  change : String
  previous : String?
  current : String?
} derive(ToJson)

///|
pub extend DocumentSnapshotChange with ToJson::{to_json}

///|
fn document_snapshot_key(entry : DocumentSnapshotEntry) -> String {
  @json.to_json([
    entry.document,
    entry.source,
    entry.kind,
    @json.to_json(entry.excerpt).stringify(),
  ]).stringify()
}

///|
/// Compare complete verified snapshots. Line movement is ignored, repeated
/// references share one identity, and excerpt edits are removal + addition.
pub fn compare_document_snapshots(
  previous : DocumentSnapshot,
  current : DocumentSnapshot,
) -> Array[DocumentSnapshotChange] {
  let old : Map[String, DocumentSnapshotEntry] = Map([])
  let present : Map[String, Bool] = Map([])
  let changes : Array[DocumentSnapshotChange] = []
  for entry in previous.entries {
    let key = document_snapshot_key(entry)
    if old.get(key) is None {
      old.set(key, entry)
    }
  }
  for entry in current.entries {
    let key = document_snapshot_key(entry)
    if present.get(key) is Some(_) {
      continue
    }
    present.set(key, true)
    let before = old.get(key)
    if before is Some(value) && value.observed == entry.observed {
      continue
    }
    changes.push({
      document: entry.document,
      source: entry.source,
      kind: entry.kind,
      excerpt: entry.excerpt,
      change: if before is Some(_) {
        "changed"
      } else {
        "added"
      },
      previous: before.map(value => value.observed),
      current: Some(entry.observed),
    })
  }
  for entry in previous.entries {
    let key = document_snapshot_key(entry)
    if present.get(key) is Some(_) {
      continue
    }
    present.set(key, true)
    changes.push({
      document: entry.document,
      source: entry.source,
      kind: entry.kind,
      excerpt: entry.excerpt,
      change: "removed",
      previous: Some(entry.observed),
      current: None,
    })
  }
  changes
}
