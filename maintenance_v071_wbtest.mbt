///|
test "non ASCII headings use default Unicode lowercase without transliteration" {
  for
    pair in [
      ("État CAFÉ", "état-café"),
      ("ÜBER Straße", "über-straße"),
      ("ПРИВЕТ", "привет"),
      ("İSTANBUL", "i\u{307}stanbul"),
      ("𐐀𐐁", "𐐨𐐩"),
      ("ẞ ＡＢＣ", "ß-ａｂｃ"),
      ("Հայերեն ԱԲԳ", "հայերեն-աբգ"),
      ("ᲐᲑᲒ", "აბგ"),
    ] {
    assert_eq(markdown_heading_slug(pair.0), pair.1)
  }
}

///|
test "Greek final Sigma uses cased context rather than individual characters" {
  for
    pair in [
      ("ΟΣ", "ος"),
      ("ΟΣΑ", "οσα"),
      ("Σ", "σ"),
      ("1Σ", "1σ"),
      ("A Σ", "a-σ"),
      ("ΟΣ\u{301}", "ος\u{301}"),
      ("ΑΣ\u{301}Α", "ασ\u{301}α"),
      ("AΣʼ", "aςʼ"),
      ("AΣʼA", "aσʼa"),
    ] {
    assert_eq(markdown_heading_slug(pair.0), pair.1)
  }
}

///|
test "Sigma context examines punctuation before heading punctuation removal" {
  assert_eq(markdown_heading_slug("ΑΣ.Α"), "ασα")
  assert_eq(markdown_heading_slug("ΑΣ!Α"), "αςα")
  assert_eq(markdown_heading_slug("AΣ\u{345}"), "aς\u{345}")
  assert_eq(markdown_heading_slug("AΣ\u{345}A"), "aσ\u{345}a")
  assert_eq(markdown_heading_slug("\u{345}Σ"), "\u{345}σ")
}

///|
test "rendered heading labels participate in Unicode case context" {
  assert_eq(
    markdown_heading_slug("[ÉTAT](other.md) <em>CAFÉ</em>"),
    "état-café",
  )
  assert_eq(markdown_heading_slug("Ο<em>Σ</em>"), "ος")
  assert_eq(markdown_heading_slug("[Σ](Alpha.md)"), "σ")
  assert_eq(markdown_heading_slug("`İSTANBUL`"), "i\u{307}stanbul")
}

///|
test "Unicode case collisions share ATX and Setext duplicate numbering" {
  let source = "ÉTAT\n===\none\n\n# état\ntwo\n# état-1\nthree\n# État\nfour\n"
  assert_eq(select_document_source(source, "état").text, "ÉTAT\n===\none\n")
  assert_eq(select_document_source(source, "état-1").text, "# état\ntwo")
  assert_eq(
    select_document_source(source, "état-1-1").text,
    "# état-1\nthree",
  )
  assert_eq(select_document_source(source, "état-2").text, "# État\nfour\n")
  assert_true(!select_document_source(source, "ÉTAT").ok)
}

///|
test "Unicode casing does not introduce accent normalization or case folding" {
  assert_eq(markdown_heading_slug("CAFÉ"), "café")
  assert_eq(markdown_heading_slug("CAFE\u{301}"), "cafe\u{301}")
  assert_eq(markdown_heading_slug("Straße"), "straße")
  assert_eq(markdown_heading_slug("STRASSE"), "strasse")
  assert_eq(markdown_heading_slug("I İ ı"), "i-i\u{307}-ı")
}

///|
test "Unicode heading selection excludes code and comments and stops at peers" {
  let source = "# Guide\n```md\n## État\n```\n<!--\n## État\n-->\n## ÉTAT\nStable text.\n### Détails\nChild.\n## NEXT\nOther.\n"
  let selected = select_document_source(source, "état")
  assert_true(selected.ok)
  assert_eq(selected.text, "## ÉTAT\nStable text.\n### Détails\nChild.")
  assert_true(!select_document_source(source, "état-1").ok)
  assert_true(!select_document_source(source, "missing").ok)
}
