///|
test "first reference definition wins even when a later definition looks valid" {
  for destinations in [("valid.md", "missing.md"), ("missing.md", "valid.md")] {
    let parsed = parse_document(
      "[Reference][id]\n[id]: \{destinations.0}\n[ID]: \{destinations.1}\n",
    )
    assert_eq(parsed.references.length(), 1)
    assert_eq(parsed.references[0].source, destinations.0)
    assert_true(parsed.warnings.is_empty())
  }
}

///|
test "reference labels retain punctuation spaces and nonbreaking spaces" {
  let parsed = parse_document(
    "[First][A .]\n[Second][A.]\n[Third][a  \t b]\n[Nonbreaking][a\u{A0}b]\n[A .]: spaced.md\n[A.]: compact.md\n[A B]: words.md\n",
  )
  assert_eq(parsed.references.map(r => r.source), [
    "spaced.md", "compact.md", "words.md",
  ])
  assert_eq(parsed.warnings.length(), 1)
  assert_eq(parsed.warnings[0].code, "UNRESOLVED_REFERENCE_LINK")
}

///|
test "Unicode reference labels case fold for full collapsed and shortcut references" {
  let parsed = parse_document(
    "[Accent][ÉTAT]\n[STRASSE][]\n[Σ]\n[état]: accent.md\n[Straße]: german.md\n[ς]: greek.md\n",
  )
  assert_eq(parsed.references.map(r => r.source), [
    "accent.md", "german.md", "greek.md",
  ])
  assert_true(parsed.warnings.is_empty())
  assert_eq(markdown_heading_slug("Straße"), "straße")
}

///|
test "Unicode case fold does not normalize accents or use locale specific rules" {
  let parsed = parse_document(
    "[Composed][É]\n[Decomposed][E\u{301}]\n[Dotted][İ]\n[Dotless][ı]\n[é]: composed.md\n[e\u{301}]: decomposed.md\n[i\u{307}]: dotted.md\n[I]: ordinary.md\n",
  )
  assert_eq(parsed.references.map(r => r.source), [
    "composed.md", "decomposed.md", "dotted.md",
  ])
  assert_eq(parsed.warnings.length(), 1)
}

///|
test "quoted link titles do not balance destination parentheses" {
  let parsed = parse_document(
    "[One](valid.md \"(\")\n[Two](valid.md\t'Title )')\n[Three](valid.md (Title))\n[Four](valid.md \"escaped \\\" )\")\n",
  )
  assert_eq(parsed.references.length(), 4)
  assert_true(parsed.references.all(r => r.source == "valid.md"))
  assert_true(parsed.warnings.is_empty())
}

///|
test "angle destinations and escaped punctuation preserve actual file names" {
  let parsed = parse_document(
    "[Angle](<guide(v2.md>)\n[Escaped](guide\\(v2\\).md)\n[Balanced](guide(v2).md)\n[Defined][path]\n[path]: guide\\(v2\\).md\t\"Title (\"\n",
  )
  assert_eq(parsed.references.map(r => r.source), [
    "guide(v2.md", "guide(v2).md", "guide(v2).md", "guide(v2).md",
  ])
  assert_true(parsed.warnings.is_empty())
}

///|
test "malformed destinations and link titles remain unverified" {
  for
    line in [
      "[Missing](valid.md \"unclosed)", "[Trailing](valid.md \"Title\" extra)", "[Unbalanced](guide(v2.md)",
      "[No space](<valid.md>\"Title\")", "[Angle](<valid.md)", "[Space](invalid\\ path.md)",
    ] {
    let parsed = parse_document(line)
    assert_true(parsed.references.is_empty())
    assert_eq(parsed.warnings[0].code, "UNRESOLVED_REFERENCE_LINK")
  }
}

///|
test "invalid reference definitions cannot mask the first valid definition" {
  let parsed = parse_document(
    "[Reference][id]\n[id]: missing.md extra\n[id]: missing.md \"unclosed\n[id]: valid.md \"Title (\"\n[id]: later.md\n",
  )
  // Invalid definitions render as ordinary text; their [id] shortcut links
  // also use the first valid definition instead of creating hidden sources.
  assert_eq(parsed.references.length(), 3)
  assert_true(parsed.references.all(r => r.source == "valid.md"))
  assert_true(!parsed.warnings.any(w => w.code == "UNRESOLVED_REFERENCE_LINK"))
}

///|
test "reference definitions inside code fences or comments cannot override real definitions" {
  let parsed = parse_document(
    "<!-- [id]: hidden.md -->\n```md\n[id]: example.md\n```\n[id]: actual.md\n[ID]: later.md\n[Reference][Id]\n[   ]: missing.md\n",
  )
  assert_eq(parsed.references.length(), 1)
  assert_eq(parsed.references[0].source, "actual.md")
  assert_true(parsed.warnings.is_empty())
}
