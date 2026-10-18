///|
/// A check observes bytes, not modification timestamps. Keep the lookup path as
/// well as its resolved target so a later symlink retarget is also a conflict.
priv struct DocumentInputVersion {
  path : String
  canonical : String
  kind : @fs.FileKind
  content : Bytes?
}

///|
fn remember_document_input(
  versions : Map[String, DocumentInputVersion],
  path : String,
  canonical : String,
  kind : @fs.FileKind,
  content : Bytes?,
) -> Unit {
  // Keep the first observed bytes. Existence-only observations can be upgraded
  // when a later reference actually depends on this file's content.
  match versions.get(path) {
    None => versions.set(path, { path, canonical, kind, content, })
    Some(previous) if previous.canonical == canonical &&
      previous.kind == kind &&
      previous.content is None &&
      content is Some(_) =>
      versions.set(path, { path, canonical, kind, content, })
    _ => ()
  }
}

///|
async fn document_input_is_current(version : DocumentInputVersion) -> Bool {
  try {
    if @fs.realpath(version.path) != version.canonical ||
      @fs.kind(version.path) != version.kind {
      return false
    }
    match version.content {
      None => true
      Some(expected) =>
        @fs.file_size(version.path) == expected.length().to_int64() &&
        @fs.read_file(version.path).binary() == expected
    }
  } catch {
    _ => false
  }
}

///|
/// Only regular files or absent destinations can participate in a replacement.
/// An existing symlink is refused rather than read through and later replaced.
async fn document_destination_version(path : String) -> Bytes? {
  let kind = @fs.kind(path, follow_symlink=false) catch {
    _ => {
      if @fs.exists(path) {
        fail("cannot inspect snapshot destination")
      }
      return None
    }
  }
  if kind != Regular {
    fail("snapshot destination must be a regular file")
  }
  Some(@fs.read_file(path).binary())
}

///|
priv enum DocumentSnapshotCommit {
  Saved
  InputChanged(String)
  DestinationChanged
  WriteFailed
}

///|
/// Cooperating TraceCite writers reserve the same CreateNew temporary file.
/// Under that reservation, revalidate inputs and the destination's old bytes,
/// then rename. This is optimistic validation, not a filesystem transaction:
/// an uncooperative external editor can still write after final validation.
async fn commit_document_snapshot(
  destination : String,
  expected : Bytes?,
  content : String,
  versions : Map[String, DocumentInputVersion],
  initialize~ : Bool = false,
) -> DocumentSnapshotCommit {
  let temporary = destination + ".tmp"
  if !write_new_document_file(temporary, content) {
    return WriteFailed
  }
  let mut owns_temporary = true
  defer (if owns_temporary { @fs.remove(temporary) catch { _ => () } })
  for _, version in versions {
    if !document_input_is_current(version) {
      return InputChanged(version.path)
    }
  }
  let current = document_destination_version(destination) catch {
    _ => return DestinationChanged
  }
  if current != expected {
    return DestinationChanged
  }
  @fs.rename(temporary, destination, replace=!initialize) catch {
    _ => return WriteFailed
  }
  owns_temporary = false
  Saved
}
