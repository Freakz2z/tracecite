///|
test "recursive globs include zero depth and Unicode filenames without crossing segment boundaries" {
  assert_true(document_path_pattern_matches("docs/**/*.md", "docs/guide.md"))
  assert_true(
    document_path_pattern_matches("docs/**/*.md", "docs/a/b/指南.md"),
  )
  assert_false(document_path_pattern_matches("docs/*.md", "docs/a/guide.md"))
  assert_true(document_path_pattern_matches("docs/?.md", "docs/中.md"))
  assert_true(document_path_pattern_matches("docs/?.md", "docs/😀.md"))
  assert_false(document_path_pattern_matches("docs/?.md", "docs/中文.md"))
  assert_true(document_path_pattern_matches("**/guide*.md", "guide.md"))
  assert_true(document_path_pattern_matches("docs/**/a*/?.md", "docs/api/x.md"))
  assert_false(
    document_path_pattern_matches("docs/**/a*/?.md", "docs/api/xx.md"),
  )
}

///|
test "glob validation never normalizes traversal after a wildcard into a wider scan" {
  for
    pattern in [
      "../**/*.md", "docs/**/../README.md", "docs/a**.md", "docs/***/a.md", "/docs/*.md",
      "https://example.org/?x",
    ] {
    assert_false(valid_document_path_pattern(pattern))
  }
  assert_eq(
    normalize_document_path_pattern("./docs//**/*.md"),
    Some("docs/**/*.md"),
  )
  assert_true(document_path_pattern_matches("docs/drafts/**", "docs/drafts"))
  assert_true(document_path_pattern_matches("docs", "docs/guide.md"))
  assert_false(document_path_pattern_matches("docs", "docs-other/guide.md"))
  assert_true(document_path_pattern_matches(".", "docs/guide.md"))
}

///|
test "coverage limits round trip while old configurations remain unlimited" {
  let old = parse_document_project_config("{\"version\":1}").config.unwrap()
  assert_eq(old.coverage.max_skipped_web, None)
  let policy = parse_document_project_config(
    "{\"version\":1,\"paths\":[\"docs/**/*.md\"],\"coverage\":{\"max_skipped_web\":0,\"max_unbound_snippets\":2}}",
  ).config.unwrap()
  assert_eq(policy.coverage.max_skipped_web, Some(0))
  assert_eq(policy.coverage.max_unbound_snippets, Some(2))
  let restored = parse_document_project_config(
    @json.to_json(policy).stringify(),
  ).config.unwrap()
  assert_eq(restored.paths, ["docs/**/*.md"])
  assert_eq(restored.coverage.max_unbound_snippets, Some(2))
}

///|
test "invalid coverage policies and wildcard baselines cannot silently disable checks" {
  for
    input in [
      "{\"version\":1,\"coverage\":null}", "{\"version\":1,\"coverage\":[]}", "{\"version\":1,\"coverage\":{\"max_skiped_web\":0}}",
      "{\"version\":1,\"coverage\":{\"max_skipped_web\":-1}}", "{\"version\":1,\"coverage\":{\"max_skipped_web\":0.5}}",
      "{\"version\":1,\"coverage\":{\"max_skipped_web\":true}}", "{\"version\":1,\"coverage\":{\"max_unbound_snippets\":2147483648}}",
      "{\"version\":1,\"baseline\":\"*.json\"}",
    ] {
    assert_true(parse_document_project_config(input).config is None)
  }
}

///|
test "Setext and ATX share duplicate anchors and delimit section snapshots at the title line" {
  let source = "Guide\n=====\n\nSettings\n--------\nCurrent defaults.\n\n### Details\nNested.\n\n## Settings\nSecond.\n\nEnd\n---\nDone.\n"
  assert_eq(
    select_document_source(source, "settings").text,
    "Settings\n--------\nCurrent defaults.\n\n### Details\nNested.\n",
  )
  assert_eq(
    select_document_source(source, "settings-1").text,
    "## Settings\nSecond.\n",
  )
  assert_true(select_document_source(source, "guide").ok)
  assert_true(select_document_source(source, "end").ok)
  assert_true(
    select_document_source(
      "<div><!--\nclosed -->\n</div>\n\nVisible\n---\n", "visible",
    ).ok,
  )
  assert_true(
    select_document_source(
      "<script>\nconst x = '<!--';\n</script>\nVisible\n---\n", "visible",
    ).ok,
  )
}

///|
test "Setext multiline titles use rendered labels and a soft line break" {
  let source = "A [formatted](target.md)\n`title`\n===\nText\n\nNext\n===\nOther\n"
  assert_eq(
    select_document_source(source, "a-formatted-title").text,
    "A [formatted](target.md)\n`title`\n===\nText\n",
  )
  assert_true(
    select_document_source("  中文标题\n  ----  \nText\n", "中文标题").ok,
  )
}

///|
test "Setext anchors ignore fences comments indented code list markers and horizontal rules" {
  let source = "```md\nFenced\n---\n```\n\n<!--\nCommented\n===\n-->\n\n    Indented\n    ----\n\n- Item\n---\n\n> Quote\n---\n\nNormal\n\n---\n\nReal\n-\nText\n"
  for anchor in ["fenced", "commented", "indented", "item", "quote", "normal"] {
    assert_false(select_document_source(source, anchor).ok)
  }
  assert_true(select_document_source(source, "real").ok)
}

///|
test "snapshot changes deduplicate references and distinguish null from empty excerpts" {
  let before : DocumentSnapshotEntry = {
    document: "guide.md",
    source: "source.md#settings",
    kind: "link",
    excerpt: None,
    observed: "before",
  }
  let current : DocumentSnapshotEntry = { ..before, observed: "after", }
  let changes = compare_document_snapshots(
    { version: 1, entries: [before, before], },
    { version: 1, entries: [current, current], },
  )
  assert_eq(changes.length(), 1)
  assert_eq(changes[0].change, "changed")
  assert_eq(changes[0].previous, Some("before"))
  assert_eq(changes[0].current, Some("after"))
  let edited : DocumentSnapshotEntry = { ..before, excerpt: Some(""), }
  let edited_changes = compare_document_snapshots(
    { version: 1, entries: [before], },
    { version: 1, entries: [edited], },
  )
  assert_eq(edited_changes.length(), 2)
  assert_eq(edited_changes[0].change, "added")
  assert_eq(edited_changes[1].change, "removed")
}

///|
test "Setext respects HTML block endings and list continuations while keeping inline formatting" {
  let source = "<div>\nHidden\n---\n</div>\n\n<script>\nAlso hidden\n===\n</script>\n<em>Visible</em>\n---\nText\n\n- item\nLazy continuation\n---\n\nEnd\n===\n"
  for anchor in ["hidden", "also-hidden", "lazy-continuation"] {
    assert_false(select_document_source(source, anchor).ok)
  }
  assert_true(select_document_source(source, "visible").ok)
  assert_true(select_document_source(source, "end").ok)
}

///|
test "complete snapshot comparison exposes removed references without inventing a live location" {
  let entry : DocumentSnapshotEntry = {
    document: "removed.md",
    source: "source.md",
    kind: "link",
    excerpt: None,
    observed: "",
  }
  let changes = compare_document_snapshots({ version: 1, entries: [entry], }, {
    version: 1,
    entries: [],
  })
  assert_eq(changes.length(), 1)
  assert_eq(changes[0].change, "removed")
  assert_eq(changes[0].current, None)
  assert_true(
    compare_document_snapshots({ version: 1, entries: [entry], }, {
      version: 1,
      entries: [entry],
    }).is_empty(),
  )
}
