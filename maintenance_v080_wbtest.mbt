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
