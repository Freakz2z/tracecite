///|
test "document references preserve snippet bytes and support local and ASCII quotes" {
  let parsed = parse_document(
    "# Guide\n\"timeout = 20\" ([configuration](config.toml))\n“quoted statement” ([source](source.txt))\n```toml source=config.toml\ntimeout = 20\nname = \"literal\"\n```\n[Usage](guide.md#usage)\n",
  )
  assert_true(parsed.diagnostics.is_empty())
  assert_true(parsed.warnings.is_empty())
  assert_eq(parsed.references.length(), 4)
  assert_eq(parsed.references[0].excerpt, Some("timeout = 20"))
  assert_eq(
    parsed.references[2].excerpt,
    Some("timeout = 20\nname = \"literal\""),
  )
  assert_eq(parsed.references[2].line, 4)
  assert_eq(parsed.references[3].source, "guide.md#usage")
}

///|
test "nested fences ignore citation examples and code quotes" {
  let parsed = parse_document(
    "````markdown\n```toml source=missing.toml\n\"not a citation\" ([source](missing.txt))\n```\n````\n[real](existing.md)\n",
  )
  assert_eq(parsed.unbound_snippets, 1)
  assert_eq(parsed.references.length(), 1)
  assert_eq(parsed.references[0].source, "existing.md")
  assert_true(parsed.warnings.is_empty())
}

///|
test "unassociated and unsupported citations are visible instead of silently passing" {
  let parsed = parse_document(
    "“without a source”\n[reference][id]\n\"not closed\n",
  )
  assert_eq(parsed.warnings.length(), 3)
  assert_eq(parsed.warnings[0].code, "UNASSOCIATED_QUOTE")
  assert_eq(parsed.warnings[1].code, "UNRESOLVED_REFERENCE_LINK")
  assert_eq(parsed.warnings[2].code, "UNCLOSED_QUOTE")
}

///|
test "local quote blocks and balanced Markdown destinations" {
  let parsed = parse_document(
    "> Quote: \"current setting\"\n> Source: [config](<config example.toml>)\n[other](docs/guide(v2).md)\n",
  )
  assert_true(parsed.diagnostics.is_empty())
  assert_eq(parsed.references.length(), 2)
  assert_eq(parsed.references[0].source, "config example.toml")
  assert_eq(parsed.references[1].source, "docs/guide(v2).md")
}

///|
test "quote markers inside inline code or link titles are not citations" {
  let parsed = parse_document(
    "Use `name = \"value\"` with [the \"new\" guide](guide.md).\n",
  )
  assert_true(parsed.warnings.is_empty())
  assert_eq(parsed.references.length(), 1)
}

///|
test "source-bound code is stricter than prose quoting" {
  assert_true(
    document_excerpt_matches(
      "before\nprint(\"value\")\nafter\n", "print(\"value\")", "snippet",
    ),
  )
  assert_true(
    !document_excerpt_matches("print(value)\n", "print(\"value\")", "snippet"),
  )
  assert_true(
    !document_excerpt_matches(
      "prefix_timeout = 20\n", "timeout = 20", "snippet",
    ),
  )
  assert_true(
    !document_excerpt_matches(
      "if ready:\n  run()\n", "if ready:\nrun()", "snippet",
    ),
  )
  assert_true(
    document_excerpt_matches("timeout = 20\r\n", "timeout = 20", "snippet"),
  )
}

///|
test "line selectors reject missing and inverted ranges" {
  assert_eq(
    select_document_source("one\ntwo\nthree\n", "L2-L3").text,
    "two\nthree",
  )
  assert_true(!select_document_source("one\n", "L2").ok)
  assert_true(!select_document_source("one\ntwo", "L2-L1").ok)
}

///|
test "Markdown sections handle nested and duplicate headings and fenced examples" {
  let source = "# Guide\n## Setup\nFirst\n### Details\nNested\n## Setup\nSecond\n```md\n# Fake\n```\n## End\n"
  let selected = select_document_source(source, "setup")
  assert_true(selected.ok)
  assert_eq(selected.text, "## Setup\nFirst\n### Details\nNested")
  assert_eq(
    select_document_source(source, "setup-1").text,
    "## Setup\nSecond\n```md\n# Fake\n```",
  )
  assert_true(!select_document_source(source, "fake").ok)
  assert_eq(
    markdown_heading_slug("安装与使用 `CLI`"),
    "安装与使用-cli",
  )
}

///|
test "stable source regions survive line movement" {
  let selected = select_document_source(
    "extra\n// ANCHOR: defaults\ntimeout = 20\n// ANCHOR_END: defaults\nother", "region:defaults",
  )
  assert_true(selected.ok)
  assert_eq(selected.text, "timeout = 20")
  assert_true(
    !select_document_source(
      "// ANCHOR: defaults\ntimeout = 20", "region:defaults",
    ).ok,
  )
}

///|
test "source context avoids unrelated distant page changes and preserves code punctuation" {
  let padding = "unrelated ".repeat(40)
  let first = document_source_context(
    padding + "quote appears here. tail",
    "quote appears here.",
    "quote",
  )
  let second = document_source_context(
    "changed " + padding + "quote appears here. tail",
    "quote appears here.",
    "quote",
  )
  assert_eq(first, second)
  assert_eq(
    document_source_context(
      "unrelated\ntimeout = 30\nother", "timeout = 20", "snippet",
    ),
    "timeout = 30",
  )
}

///|
test "document snapshot round trips with explicit version and portable paths" {
  let snapshot : DocumentSnapshot = {
    version: 1,
    entries: [
      {
        document: "docs/guide.md",
        source: "../config.toml",
        kind: "snippet",
        excerpt: Some("timeout = 20"),
        observed: "timeout = 20",
      },
    ],
  }
  let decoded : DocumentSnapshot = @json.from_json(@json.to_json(snapshot))
  assert_eq(decoded.entries[0].document, "docs/guide.md")
  assert_eq(decoded.entries[0].observed, "timeout = 20")
}

///|
test "reference-style links resolve definitions without changing the document" {
  let parsed = parse_document(
    "\"current setting\" ([Settings][CONFIG])\n[config][] and [config]\n[config]: config.toml \"optional title\"\n",
  )
  assert_true(parsed.warnings.is_empty())
  assert_eq(parsed.references.length(), 3)
  assert_eq(parsed.references[0].kind, "quote")
  assert_eq(parsed.references[0].source, "config.toml")
}

///|
test "matched code context selects the actual excerpt rather than an earlier similar block" {
  let source = "import {\n  different\n}\nimport {\n  expected\n}\n"
  let excerpt = "import {\n  expected\n}"
  assert_eq(document_source_context(source, excerpt, "snippet"), excerpt)
}

///|
test "section scanning keeps inner triple fences inside outer four-backtick examples" {
  let source = "# Guide\n````markdown\n```sh\n# False heading\n```\n````\n## Real\nActual text\n"
  assert_true(!select_document_source(source, "false-heading").ok)
  assert_true(select_document_source(source, "real").ok)
}

///|
test "commented examples cannot create document dependencies" {
  let parsed = parse_document(
    "<!--\n```toml source=missing.toml\nvalue = 0\n```\n[hidden](missing.md)\n--> [visible](real.md)\n",
  )
  assert_true(parsed.diagnostics.is_empty())
  assert_true(parsed.warnings.is_empty())
  assert_eq(parsed.references.length(), 1)
  assert_eq(parsed.references[0].source, "real.md")
}

///|
test "linked badge images include both nested and outer destinations" {
  let parsed = parse_document(
    "[![badge](badge.svg)](guide.md)\n[truncated](missing.md\n",
  )
  assert_eq(parsed.references.length(), 2)
  assert_eq(parsed.references[0].source, "badge.svg")
  assert_eq(parsed.references[1].source, "guide.md")
  assert_eq(parsed.warnings[0].code, "UNRESOLVED_REFERENCE_LINK")
}

///|
test "README HTML attributes are links and presentation rather than prose quotations" {
  let parsed = parse_document(
    "<p align=\"center\">\n<img src=\"assets/hero.svg\" width=\"100%\" alt=\"A quoted description\">\n</p>\n<a href='guide.md'>Guide</a>\n",
  )
  assert_true(parsed.warnings.is_empty())
  assert_eq(parsed.references.length(), 2)
  assert_eq(parsed.references[0].source, "assets/hero.svg")
  assert_eq(parsed.references[1].source, "guide.md")
}
