///|
fn document_diagnostic_category(status : String, code : String) -> String {
  if code == "SKIPPED_WEB_LIMIT_EXCEEDED" ||
    code == "UNBOUND_SNIPPET_LIMIT_EXCEEDED" ||
    code == "SKIPPED_QUOTE_LIMIT_EXCEEDED" {
    "coverage"
  } else {
    match status {
      "ok" => "verified"
      "unavailable" => "source_unavailable"
      "mismatch" => "content_mismatch"
      "changed" => "source_changed"
      "warning" => "needs_review"
      "skipped" => "not_checked"
      _ => "invalid_document"
    }
  }
}

///|
fn remote_failure_message(code : String) -> String {
  if code.has_prefix("HTTP_STATUS_") {
    let status = code[12:].to_owned()
    "source request returned HTTP \{status}; check access or service availability before reviewing the excerpt"
  } else {
    match code {
      "REQUEST_TIMEOUT" =>
        "source request timed out after 20 seconds; retry or check network and proxy settings"
      "HTTP_REQUEST_FAILED" =>
        "source request failed before receiving a response; check DNS, TLS, network and proxy settings"
      "PROXY_CONNECTION_FAILED" =>
        "could not connect through the configured proxy; check proxy availability"
      "INVALID_PROXY_URL" =>
        "configured proxy URL is unsupported; check HTTP_PROXY and HTTPS_PROXY settings"
      "INVALID_OR_BLOCKED_URL" | "URL_BLOCKED" | "HOST_UNRESOLVED" =>
        "source URL could not be reached under the public-source policy; check the address and DNS configuration"
      "HTTPS_DOWNGRADE_REDIRECT" =>
        "source redirected from HTTPS to HTTP; use a verified HTTPS source"
      "TOO_MANY_REDIRECTS" =>
        "source exceeded the redirect limit; use its final public URL"
      "REDIRECT_WITHOUT_LOCATION" | "INVALID_REDIRECT_TARGET" =>
        "source returned an unusable redirect; check the destination URL"
      "SOURCE_TOO_LARGE" =>
        "source exceeded the 2 MiB read limit; use a smaller independently readable source"
      "UNSUPPORTED_CONTENT_TYPE" =>
        "source response is not supported text or HTML; images, PDFs and binary content require another source"
      "SOURCE_NOT_UTF8" =>
        "source text is not valid UTF-8; provide a readable UTF-8 source"
      "HTML_PARSE_FAILED" =>
        "source response could not be parsed as readable HTML; provide a readable text source"
      "HTTP_BODY_READ_FAILED" | "INVALID_CONTENT_LENGTH" =>
        "source response body could not be read completely; retry or check the server response"
      _ =>
        "source cannot be independently read; resolve the access failure before reviewing the excerpt"
    }
  }
}
