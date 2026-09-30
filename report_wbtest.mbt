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

///|
test "Markdown report extracts multiple natural inline quote links" {
  let report = "# Memo\n“First exact quote” ([source](https://example.org/one)) and “Second `exact` quote”（[source](https://example.org/two)）.\n"
  let parsed = parse_markdown_report(report)
  assert_true(parsed.diagnostics.is_empty())
  assert_eq(parsed.notes.length(), 2)
  assert_eq(parsed.notes[0].quote, "First exact quote")
  assert_eq(parsed.notes[0].url, "https://example.org/one")
  assert_eq(parsed.notes[0].line, 2)
  assert_eq(parsed.notes[1].quote, "Second exact quote")
  assert_eq(parsed.notes[1].url, "https://example.org/two")
}

///|
test "Markdown report ignores prose links and code examples" {
  let report = "# Memo\nA claim with [link](https://example.org) has no quote.\n```markdown\n“example” ([source](https://example.org))\n```\n"
  let parsed = parse_markdown_report(report)
  assert_true(parsed.notes.is_empty())
  assert_eq(parsed.diagnostics[0].code, "NO_REPORT_CITATIONS")
}

///|
test "Markdown report rejects invalid inline citation URL" {
  let parsed = parse_markdown_report(
    "“quote” ([source](file:///private.txt))\n",
  )
  assert_true(parsed.notes.is_empty())
  assert_eq(parsed.diagnostics[0].code, "INVALID_REPORT_SOURCE")
}

///|
test "Markdown report associates a same-sentence source after a quote" {
  let parsed = parse_markdown_report(
    "出现“API token saved to ~/.moon/credentials.json”即表示登录成功（[账号设置](https://example.org/login)）。\n",
  )
  assert_true(parsed.diagnostics.is_empty())
  assert_eq(parsed.notes.length(), 1)
  assert_eq(
    parsed.notes[0].quote,
    "API token saved to ~/.moon/credentials.json",
  )
}

///|
test "Markdown report associates an English same-sentence link" {
  let parsed = parse_markdown_report(
    "The guide says “Use moon package --list” before publication ([official](https://example.org/publish)).\n",
  )
  assert_true(parsed.diagnostics.is_empty())
  assert_eq(parsed.notes.length(), 1)
  assert_eq(parsed.notes[0].url, "https://example.org/publish")
}

///|
test "Markdown report checks a quoted excerpt after a linked list title" {
  let parsed = parse_markdown_report(
    "- [Official guide](https://example.org/guide) - “Use the current package format.”\n",
  )
  assert_true(parsed.diagnostics.is_empty())
  assert_eq(parsed.notes.length(), 1)
  assert_eq(parsed.notes[0].url, "https://example.org/guide")
  assert_eq(parsed.notes[0].quote, "Use the current package format.")
}

///|
test "Markdown report accepts a trailing attribution link" {
  let parsed = parse_markdown_report(
    "- “A short exact excerpt from a source.” - An [archived slide](https://example.org/slide).\n",
  )
  assert_true(parsed.diagnostics.is_empty())
  assert_eq(parsed.notes.length(), 1)
  assert_eq(parsed.notes[0].url, "https://example.org/slide")
}

///|
test "mixed straight and curly quotation styles cannot hide a citation" {
  let parsed = parse_markdown_report(
    "“valid quotation” ([source](https://example.org))\n\"incorrect quotation\" ([source](https://example.org))\n",
  )
  assert_eq(parsed.notes.length(), 2)
  assert_eq(parsed.notes[1].quote, "incorrect quotation")
}
