///|
test "change context preserves short replacements insertions and deletions" {
  assert_eq(document_change_context("before", "after"), ("before", "after"))
  assert_eq(document_change_context("ab", "a新😀b"), ("ab", "a新😀b"))
  assert_eq(document_change_context("a新😀b", "ab"), ("a新😀b", "ab"))
  assert_eq(document_change_context("", "new"), ("", "new"))
  assert_eq(document_change_context("old", ""), ("old", ""))
  assert_eq(document_change_context("same", "same"), ("same", "same"))
  assert_eq(document_change_context("", ""), ("", ""))
}

///|
test "change context finds late edits without splitting Unicode characters" {
  let padding = String::from_array(Array::make(2000, '😀'))
  let (before, after) = document_change_context(
    padding + "OLD" + padding,
    padding + "NEW" + padding,
  )
  let context = String::from_array(Array::make(100, '😀'))
  assert_eq(before, "…\n" + context + "OLD" + context + "\n…")
  assert_eq(after, "…\n" + context + "NEW" + context + "\n…")
}

///|
test "change context bounds large replacements and shows the first edit" {
  let padding = String::from_array(Array::make(2000, 'x'))
  let (before, after) = document_change_context(
    padding + "OLD" + padding + "old tail",
    padding + "NEW" + padding + "new tail",
  )
  assert_true(before.contains("OLD"))
  assert_true(after.contains("NEW"))
  assert_true(before.has_suffix("\n…"))
  assert_true(after.has_suffix("\n…"))
  assert_true(before.to_array().length() <= 1600)
  assert_true(after.to_array().length() <= 1600)
  let (same, _) = document_change_context(padding, padding)
  assert_true(same.to_array().length() <= 1600)
}

///|
test "old configurations keep unassociated quotes under review" {
  let config = parse_document_project_config("{\"version\":1}").config.unwrap()
  assert_eq(config.unassociated_quotes, "review")
  assert_eq(config.coverage.max_skipped_quotes, None)
  let parsed = parse_document("The \"fast\" and \"safe\" modes.\n")
  assert_eq(parsed.warnings.length(), 2)
  assert_true(parsed.warnings.all(item => item.code == "UNASSOCIATED_QUOTE"))
}

///|
test "explicit quote policy and its budget survive configuration round trip" {
  let input = "{\"version\":1,\"unassociated_quotes\":\"skip\",\"coverage\":{\"max_skipped_quotes\":2}}"
  let config = parse_document_project_config(input).config.unwrap()
  let restored = parse_document_project_config(
    @json.to_json(config).stringify(),
  ).config.unwrap()
  assert_eq(restored.unassociated_quotes, "skip")
  assert_eq(restored.coverage.max_skipped_quotes, Some(2))
  assert_true(restored.strict)
}

///|
test "invalid quote policy or budget cannot silently disable review" {
  for value in ["null", "true", "0", "[]", "\"ignore\"", "\"SKIP\""] {
    let result = parse_document_project_config(
      "{\"version\":1,\"unassociated_quotes\":" + value + "}",
    )
    assert_true(result.config is None)
    assert_eq(result.diagnostics[0].code, "INVALID_QUOTE_POLICY")
  }
  for value in ["true", "-1", "0.5", "\"2\"", "2147483648"] {
    let result = parse_document_project_config(
      "{\"version\":1,\"coverage\":{\"max_skipped_quotes\":" + value + "}}",
    )
    assert_true(result.config is None)
    assert_eq(result.diagnostics[0].code, "INVALID_COVERAGE_LIMIT")
  }
}
