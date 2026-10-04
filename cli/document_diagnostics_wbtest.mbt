///|
test "source retrieval failures stay distinct from content and baseline review" {
  assert_eq(
    document_diagnostic_category("unavailable", "HTTP_STATUS_403"),
    "source_unavailable",
  )
  assert_eq(
    document_diagnostic_category("mismatch", "DOCUMENT_EXCERPT_MISMATCH"),
    "content_mismatch",
  )
  assert_eq(
    document_diagnostic_category("changed", "REFERENCED_SOURCE_CHANGED"),
    "source_changed",
  )
  assert_eq(
    document_diagnostic_category("warning", "REFERENCE_NOT_IN_BASELINE"),
    "needs_review",
  )
  assert_eq(
    document_diagnostic_category("skipped", "WEB_SOURCE_SKIPPED"),
    "not_checked",
  )
  assert_eq(
    document_diagnostic_category("error", "SKIPPED_WEB_LIMIT_EXCEEDED"),
    "coverage",
  )
}

///|
test "web diagnostics explain the available evidence without claiming citation failure" {
  assert_true(remote_failure_message("HTTP_STATUS_403").contains("HTTP 403"))
  assert_true(remote_failure_message("REQUEST_TIMEOUT").contains("20 seconds"))
  assert_true(
    remote_failure_message("UNSUPPORTED_CONTENT_TYPE").contains("PDFs"),
  )
  assert_true(
    remote_failure_message("HTTPS_DOWNGRADE_REDIRECT").contains("HTTPS to HTTP"),
  )
  assert_true(
    remote_failure_message("UNKNOWN_FUTURE_ERROR").contains(
      "resolve the access failure",
    ),
  )
}
