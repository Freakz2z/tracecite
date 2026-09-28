///|
test "Markdown report extracts rendered quotes and source URLs with line numbers" {
  let report = "# Memo\n\n```markdown\n> 原文：“ignored”\n> 来源：[x](https://example.org/ignored)\n```\n\n## Publishing\n> 原文：“use `moon publish` to push a module”\n> 来源：[official](https://example.org/publish)\n\n> Quote: \"run `moon test` first\"\n> Source: https://example.org/test\n"
  let parsed = parse_markdown_report(report)
  assert_true(parsed.diagnostics.is_empty())
  assert_eq(parsed.notes.length(), 2)
  assert_eq(parsed.notes[0].claim, "Publishing")
  assert_eq(parsed.notes[0].quote, "use moon publish to push a module")
  assert_eq(parsed.notes[0].url, "https://example.org/publish")
  assert_eq(parsed.notes[0].line, 9)
  assert_eq(parsed.notes[1].quote, "run moon test first")
  assert_eq(parsed.notes[1].line, 12)
}

///|
test "Markdown report rejects missing and orphaned sources" {
  let report = "> 原文：“missing source”\nThis is another paragraph.\n> 来源：[official](https://example.org/publish)\n"
  let parsed = parse_markdown_report(report)
  assert_true(parsed.notes.is_empty())
  assert_eq(parsed.diagnostics.length(), 2)
  assert_eq(parsed.diagnostics[0].code, "MISSING_REPORT_SOURCE")
  assert_eq(parsed.diagnostics[0].line, 1)
  assert_eq(parsed.diagnostics[1].code, "SOURCE_WITHOUT_QUOTE")
  assert_eq(parsed.diagnostics[1].line, 3)
}

///|
test "Markdown report requires a citation block" {
  let parsed = parse_markdown_report("# Report\nNo quoted sources here.\n")
  assert_true(parsed.notes.is_empty())
  assert_eq(parsed.diagnostics[0].code, "NO_REPORT_CITATIONS")
}
