///|
async fn consistency_fixture() -> (
  String,
  String,
  Map[String, DocumentInputVersion],
) {
  let directory = @fs.tmpdir(prefix="tracecite-consistency-")
  let source = directory + "/source.md"
  @fs.write_file(source, "timeout = 20\n")
  let versions : Map[String, DocumentInputVersion] = Map([])
  remember_document_input(
    versions,
    source,
    @fs.realpath(source),
    Regular,
    Some(@utf8.encode("timeout = 20\n")),
  )
  (directory, source, versions)
}

///|
async test "source changes after a successful observation cannot enter the baseline" {
  let (directory, source, versions) = consistency_fixture()
  defer @fs.rmdir(directory, recursive=true)
  let destination = directory + "/baseline.json"
  @fs.write_file(destination, "previous baseline\n")
  let expected = document_destination_version(destination)
  // Same byte count: an mtime/size-only guard would miss this change.
  @fs.write_file(source, "timeout = 30\n")
  let result = commit_document_snapshot(
    destination, expected, "stale candidate\n", versions,
  )
  assert_true(result is InputChanged(path) && path == source)
  assert_eq(@fs.read_file(destination).text(), "previous baseline\n")
  assert_false(@fs.exists(destination + ".tmp"))
}

///|
async test "the first version remains authoritative and removed inputs fail closed" {
  let (directory, source, versions) = consistency_fixture()
  defer @fs.rmdir(directory, recursive=true)
  @fs.write_file(source, "timeout = 30\n")
  remember_document_input(
    versions,
    source,
    @fs.realpath(source),
    Regular,
    Some(@utf8.encode("timeout = 30\n")),
  )
  assert_false(document_input_is_current(versions.get(source).unwrap()))
  @fs.remove(source)
  assert_false(document_input_is_current(versions.get(source).unwrap()))
  let destination = directory + "/new.json"
  let result = commit_document_snapshot(
    destination,
    None,
    "candidate\n",
    versions,
    initialize=true,
  )
  assert_true(result is InputChanged(_))
  assert_false(@fs.exists(destination))
}

///|
async test "a plain link later used by a snippet also guards its observed bytes" {
  let (directory, source, _) = consistency_fixture()
  defer @fs.rmdir(directory, recursive=true)
  let versions : Map[String, DocumentInputVersion] = Map([])
  let canonical = @fs.realpath(source)
  remember_document_input(versions, source, canonical, Regular, None)
  remember_document_input(
    versions,
    source,
    canonical,
    Regular,
    Some(@utf8.encode("timeout = 20\n")),
  )
  @fs.write_file(source, "timeout = 30\n")
  assert_false(document_input_is_current(versions.get(source).unwrap()))
}

///|
async test "existence-only links ignore content but detect removal and symlink retargeting" {
  let (directory, source, _) = consistency_fixture()
  defer @fs.rmdir(directory, recursive=true)
  let link = directory + "/link.md"
  @fs.symlink(link, target=source)
  let version : DocumentInputVersion = {
    path: link,
    canonical: @fs.realpath(source),
    kind: Regular,
    content: None,
  }
  @fs.write_file(source, "new unobserved content\n")
  assert_true(document_input_is_current(version))
  let other = directory + "/other.md"
  @fs.write_file(other, "new unobserved content\n")
  @fs.remove(link)
  @fs.symlink(link, target=other)
  assert_false(document_input_is_current(version))
  @fs.remove(link)
  assert_false(document_input_is_current(version))
}

///|
async test "a stale writer cannot overwrite a newer committed baseline" {
  let (directory, _, versions) = consistency_fixture()
  defer @fs.rmdir(directory, recursive=true)
  let destination = directory + "/baseline.json"
  @fs.write_file(destination, "old\n")
  let writer_a = document_destination_version(destination)
  let writer_b = document_destination_version(destination)
  assert_true(
    commit_document_snapshot(destination, writer_a, "writer A\n", versions)
    is Saved,
  )
  assert_true(
    commit_document_snapshot(destination, writer_b, "writer B\n", versions)
    is DestinationChanged,
  )
  assert_eq(@fs.read_file(destination).text(), "writer A\n")
  assert_false(@fs.exists(destination + ".tmp"))
  let fresh = document_destination_version(destination)
  assert_true(
    commit_document_snapshot(destination, fresh, "reviewed retry\n", versions)
    is Saved,
  )
  assert_eq(@fs.read_file(destination).text(), "reviewed retry\n")
}

///|
async test "an absent baseline becoming present is a conflict and reservations are not removed" {
  let (directory, _, versions) = consistency_fixture()
  defer @fs.rmdir(directory, recursive=true)
  let destination = directory + "/baseline.json"
  let expected = document_destination_version(destination)
  @fs.write_file(destination, "other creator\n")
  assert_true(
    commit_document_snapshot(
      destination,
      expected,
      "stale creator\n",
      versions,
      initialize=true,
    )
    is DestinationChanged,
  )
  assert_eq(@fs.read_file(destination).text(), "other creator\n")
  @fs.write_file(destination + ".tmp", "another writer owns this\n")
  assert_true(
    commit_document_snapshot(
      destination,
      Some(@utf8.encode("other creator\n")),
      "candidate\n",
      versions,
    )
    is WriteFailed,
  )
  assert_eq(
    @fs.read_file(destination + ".tmp").text(),
    "another writer owns this\n",
  )
  assert_eq(@fs.read_file(destination).text(), "other creator\n")
}

///|
async test "snapshot symlinks are refused without modifying their target" {
  let (directory, source, _) = consistency_fixture()
  defer @fs.rmdir(directory, recursive=true)
  let destination = directory + "/baseline.json"
  @fs.symlink(destination, target=source)
  let refused = try {
    ignore(document_destination_version(destination))
    false
  } catch {
    _ => true
  }
  assert_true(refused)
  assert_eq(@fs.read_file(source).text(), "timeout = 20\n")
}
