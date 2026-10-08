///|
test "standalone HTML ids resolve a following paragraph" {
  let source = "<a id=\"default-alias\"></a>\n\nAlias body.\n\n## Next\nOther."
  let selected = select_document_source(source, "default-alias")
  assert_true(selected.ok)
  assert_eq(selected.text, "<a id=\"default-alias\"></a>\n\nAlias body.\n")
}
