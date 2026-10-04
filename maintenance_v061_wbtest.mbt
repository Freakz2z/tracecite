///|
test "GitHub punctuation anchors retain letters emoji and existing separators" {
  assert_eq(
    markdown_heading_slug("Blocking(n) — Backpressure"),
    "blockingn--backpressure",
  )
  assert_eq(
    markdown_heading_slug("中文：维护、复核！"),
    "中文维护复核",
  )
  assert_eq(
    markdown_heading_slug("état… café «déjà»"),
    "état-café-déjà",
  )
  assert_eq(
    markdown_heading_slug("日本語・タイトル"),
    "日本語タイトル",
  )
  assert_eq(markdown_heading_slug("a_b-c 🚀"), "a_b-c-🚀")
  assert_eq(
    markdown_heading_slug("[Guide](path) — <em>Next</em>"),
    "guide--next",
  )
}

///|
test "punctuation anchors work for Setext and duplicate headings" {
  let source = "Blocking(n) — Backpressure\n===\nfirst\n\n# Blocking(n) — Backpressure\nsecond\n"
  assert_true(select_document_source(source, "blockingn--backpressure").ok)
  assert_true(select_document_source(source, "blockingn--backpressure-1").ok)
}

///|
test "footnotes are not file links and their body links remain visible" {
  let parsed = parse_document(
    "There are four targets [Architecture][][^subpkg].\n\n[^subpkg]: The internal target is reserved; see [details](detail.md).\n[architecture]: arch.md\n",
  )
  assert_eq(parsed.references.length(), 2)
  assert_eq(parsed.references[0].source, "arch.md")
  assert_eq(parsed.references[1].source, "detail.md")
  assert_true(parsed.diagnostics.is_empty())
  assert_true(parsed.warnings.is_empty())
}

///|
test "footnote definition cannot override ordinary reference definitions" {
  let parsed = parse_document(
    "[ordinary][id] [^id]\n[id]: valid.md\n[^id]: Missing words are not a destination.\n",
  )
  assert_eq(parsed.references.length(), 1)
  assert_eq(parsed.references[0].source, "valid.md")
  assert_true(parsed.warnings.is_empty())
}

///|
test "caret labels on explicit Markdown links remain ordinary dependencies" {
  let parsed = parse_document(
    "[^label](valid.md) [^other][destination]\n[destination]: another.md\n",
  )
  assert_eq(parsed.references.length(), 2)
  assert_eq(parsed.references[0].source, "valid.md")
  assert_eq(parsed.references[1].source, "another.md")
}
