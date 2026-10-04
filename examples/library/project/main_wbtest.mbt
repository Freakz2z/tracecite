///|
test "changed configuration requires document maintenance" {
  let result = maintain_example()
  assert_eq(result.references, 1)
  assert_true(result.before_matches)
  assert_false(result.after_matches)
  assert_eq(result.changes.length(), 1)
  assert_eq(result.changes[0].document, "guide.md")
  assert_eq(result.changes[0].previous, Some("timeout = 20"))
  assert_eq(result.changes[0].current, Some("timeout = 30"))
}
