///|
test "project configuration defaults to a strict offline scan" {
  let parsed = parse_document_project_config("{\"version\":1}")
  assert_true(parsed.diagnostics.is_empty())
  let config = parsed.config.unwrap()
  assert_eq(config.paths, ["."])
  assert_true(config.strict)
  assert_false(config.online)
  assert_eq(config.baseline, None)
  let restored = parse_document_project_config(
    @json.to_json(config).stringify(),
  )
  assert_true(restored.diagnostics.is_empty())
  assert_eq(restored.config.unwrap().baseline, None)
}

///|
test "project configuration preserves explicit policy and paths with spaces" {
  let parsed = parse_document_project_config(
    "{\"version\":1,\"paths\":[\"docs/guide with spaces.md\"],\"exclude\":[\"docs/drafts\"],\"baseline\":\"references.json\",\"strict\":false,\"online\":true}",
  )
  assert_true(parsed.diagnostics.is_empty())
  let config = parsed.config.unwrap()
  assert_eq(config.paths[0], "docs/guide with spaces.md")
  assert_eq(config.exclude, ["docs/drafts"])
  assert_eq(config.baseline, Some("references.json"))
  assert_false(config.strict)
  assert_true(config.online)
  let restored = parse_document_project_config(
    @json.to_json(config).stringify(),
  )
  assert_eq(restored.config.unwrap().baseline, config.baseline)
}

///|
test "misspelled project policy fields are rejected instead of ignored" {
  let parsed = parse_document_project_config("{\"version\":1,\"strcit\":true}")
  assert_true(parsed.config is None)
  assert_eq(parsed.diagnostics[0].code, "UNKNOWN_CONFIG_FIELD")
}

///|
test "configuration versions and policy types are validated" {
  for
    input in [
      "{}", "{\"version\":2}", "{\"version\":\"1\"}", "{\"version\":1,\"strict\":\"false\"}",
      "{\"version\":1,\"online\":null}",
    ] {
    let parsed = parse_document_project_config(input)
    assert_true(parsed.config is None)
    assert_true(!parsed.diagnostics.is_empty())
  }
}

///|
test "portable scan paths cannot escape the root or select a URI" {
  for
    path in [
      "../docs", "/tmp/docs", "https://example.org/", "docs/../../other", "C:\\docs",
      "",
    ] {
    let input : Json = { "version": 1, "paths": [path] }
    let parsed = parse_document_project_config(input.stringify())
    assert_true(parsed.config is None)
  }
  let parsed = parse_document_project_config(
    "{\"version\":1,\"paths\":[\"docs/../README.md\"]}",
  )
  assert_true(parsed.diagnostics.is_empty())
  assert_eq(parsed.config.unwrap().paths, ["README.md"])
}

///|
test "configuration cannot silently turn an empty or invalid scope into a full scan" {
  for
    input in [
      "{\"version\":1,\"paths\":[]}", "{\"version\":1,\"paths\":\"docs\"}", "{\"version\":1,\"paths\":[null]}",
      "{\"version\":1,\"exclude\":[\"../other\"]}",
    ] {
    assert_true(parse_document_project_config(input).config is None)
  }
}

///|
test "configuration baselines require a relative JSON filename" {
  for path in ["", "../references.json", "/tmp/references.json", "README.md"] {
    let input : Json = { "version": 1, "baseline": path }
    assert_true(parse_document_project_config(input.stringify()).config is None)
  }
}

///|
test "configuration rejects invalid JSON and non-object documents" {
  for input in ["[", "null", "[]", "true"] {
    let parsed = parse_document_project_config(input)
    assert_true(parsed.config is None)
    assert_eq(parsed.diagnostics[0].code, "INVALID_PROJECT_CONFIG")
  }
}
