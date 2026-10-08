///|
test "standalone HTML ids resolve a following paragraph" {
  let source = "<a id=\"default-alias\"></a>\n\nAlias body.\n\n## Next\nOther."
  let selected = select_document_source(source, "default-alias")
  assert_true(selected.ok)
  assert_eq(selected.text, "<a id=\"default-alias\"></a>\n\nAlias body.\n")
}

///|
test "standalone anchor before a heading includes its nested sections" {
  let source = "<a id='stable'></a>\n\n## Renamable\nBody.\n\n### Nested\nDetail.\n\n## Next\nOutside."
  let selected = select_document_source(source, "stable")
  assert_true(selected.ok)
  assert_true(selected.text.contains("Detail."))
  assert_false(selected.text.contains("Outside."))
  assert_true(document_excerpt_matches(selected.text, "Body.", "quote"))
  assert_false(document_excerpt_matches(selected.text, "Outside.", "quote"))
}

///|
test "standalone anchor scope ends at the next explicit anchor" {
  let source = "<a id=one></a>\n\nFirst.\n\n<a id=two></a>\n\nSecond."
  assert_eq(
    select_document_source(source, "one").text,
    "<a id=one></a>\n\nFirst.\n",
  )
  assert_true(select_document_source(source, "two").text.contains("Second."))
}

///|
test "standalone ids preserve case Unicode and basic HTML entities" {
  let source = "<A title='ignored id=fake' ID=\"Mixed-É&amp;&quot;\"></A>\n\nBody."
  assert_true(select_document_source(source, "Mixed-É&\"").ok)
  assert_false(select_document_source(source, "mixed-é&\"").ok)
  assert_false(select_document_source(source, "fake").ok)
  assert_true(
    select_document_source("<a id=Library></a>\n\nBody.", "Library").ok,
  )
  assert_eq(select_document_source("one\ntwo", "L2").text, "two")
  assert_false(select_document_source("one", "L2").ok)
}

///|
test "duplicate HTML ids and heading collisions select the first target" {
  let duplicated = "<a id=x></a>\n\nFirst.\n\n<a id=x></a>\n\nSecond."
  assert_false(select_document_source(duplicated, "x").text.contains("Second."))
  let html_first = "<a id=x></a>\n\nFirst.\n\n## x\nSecond."
  assert_false(select_document_source(html_first, "x").text.contains("Second."))
  let heading_first = "## x\nFirst.\n\n## End\n\n<a id=x></a>\n\nSecond."
  assert_false(
    select_document_source(heading_first, "x").text.contains("Second."),
  )
  assert_false(
    select_document_source("<a id=first id=second></a>\n\nBody.", "second").ok,
  )
  assert_true(
    select_document_source("<a id=first id=second></a>\n\nBody.", "first").ok,
  )
}

///|
test "HTML anchor lookalikes in hidden or unsupported contexts stay unresolved" {
  for
    source in [
      "```html\n<a id=x></a>\n```\n", "~~~html\n<a id=x></a>\n~~~\n", "    <a id=x></a>\n",
      "\t<a id=x></a>\n", "<!--\n<a id=x></a>\n-->\n", "`<a id=x></a>`\n", "\\<a id=x></a>\n",
      "prefix <a id=x></a>\n", "<div>\n<a id=x></a>\n</div>\n", "<script>\n<a id=x></a>\n</script>\n",
      "<pre>\n<a id=x></a>\n</pre>\n", "> <a id=x></a>\n", "- <a id=x></a>\n", "<a data-id=x></a>\n",
      "<a name=x></a>\n", "<a id=x>Visible text</a>\n", "<a id=x>\n", "<a id=\"x></a>\n",
      "<a id=''></a>\n", "<a id='bad id'></a>\n", "<a id='&#120;'></a>\n",
    ] {
    assert_false(select_document_source(source, "x").ok)
  }
}

///|
test "unsupported entities and an empty first id cannot invent HTML targets" {
  assert_false(select_document_source("<a id id=x></a>\n\nBody.", "x").ok)
  assert_false(
    select_document_source("<a id='&copy;'></a>\n\nBody.", "&copy;").ok,
  )
  assert_false(select_document_source("<a id='a&b'></a>\n\nBody.", "a&b").ok)
  assert_true(select_document_source("<a id='a&amp;b'></a>\n\nBody.", "a&b").ok)
}
