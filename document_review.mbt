///|
/// Paired display excerpts around the first changed character, with up to 100
/// unchanged characters on either side. Each excerpt is at most 1600 characters;
/// ellipses mark omitted text. This is not a complete diff or a snapshot.
pub fn document_change_context(
  previous : String,
  current : String,
) -> (String, String) {
  let before = previous.to_array()
  let after = current.to_array()
  let mut prefix = 0
  while prefix < before.length() &&
        prefix < after.length() &&
        before[prefix] == after[prefix] {
    prefix += 1
  }
  let mut suffix = 0
  while suffix < before.length() - prefix &&
        suffix < after.length() - prefix &&
        before[before.length() - suffix - 1] ==
        after[after.length() - suffix - 1] {
    suffix += 1
  }
  let start = if previous == current { 0 } else { Int::max(0, prefix - 100) }
  (
    document_change_excerpt(before, start, before.length() - suffix + 100),
    document_change_excerpt(after, start, after.length() - suffix + 100),
  )
}

///|
fn document_change_excerpt(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> String {
  let end = Int::min(chars.length(), Int::min(end, start + 1596))
  let text = String::from_array(chars[start:end])
  let text = if start > 0 { "…\n" + text } else { text }
  if end < chars.length() {
    text + "\n…"
  } else {
    text
  }
}

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
