///|
priv struct RemoteUrl {
  scheme : String
  host : String
  port : Int
  path : String
  full : String
}

///|
priv struct RemoteFetch {
  ok : Bool
  text : String
  error_code : String?
}

///|
priv struct UrlCheckItem {
  index : Int
  url : String
  ok : Bool
  citation_count : Int
  matched_count : Int
  diagnostics : Array[String]
} derive(ToJson)

///|
priv struct UrlCheckReport {
  source_count : Int
  citation_count : Int
  matched_count : Int
  items : Array[UrlCheckItem]
} derive(ToJson)

///|
priv struct CitationInputErrors {
  diagnostics : Array[@tracecite.Diagnostic]
} derive(ToJson)

///|
async fn verify_urls_command(path : String, json_output : Bool) -> Int {
  let input = @fs.read_file(path).text() catch {
    _ => {
      @stdio.stderr.write("Cannot read input file: \{path}\n")
      return 1
    }
  }
  let report = @tracecite.validate_evidence_jsonl(input)
  if !report.ok() {
    @stdio.stdout.write("FAIL: trace evidence validation failed\n")
    for diagnostic in report.diagnostics {
      @stdio.stdout.write(
        "  line \{diagnostic.line} [\{diagnostic.code}] \{diagnostic.message}\n",
      )
    }
    return 2
  }

  let items : Array[UrlCheckItem] = []
  let mut citation_count = 0
  let mut matched_count = 0
  for source in report.sources {
    let result = fetch_public_text(source.uri)
    let checks = @tracecite.check_live_source_quotes(
      input,
      source.uri,
      if result.ok {
        result.text
      } else {
        ""
      },
    )
    let diagnostics : Array[String] = []
    if !result.ok {
      diagnostics.push(result.error_code.unwrap_or("SOURCE_UNAVAILABLE"))
    } else if checks.is_empty() {
      diagnostics.push("NO_CITATIONS_FOR_SOURCE")
    } else {
      for check in checks {
        if check.quote_present {
          matched_count = matched_count + 1
        } else {
          diagnostics.push(
            "QUOTE_NOT_IN_LIVE_SOURCE:claim-\{check.claim_index}",
          )
        }
      }
    }
    citation_count = citation_count + checks.length()
    items.push({
      index: items.length() + 1,
      url: source.uri,
      ok: result.ok && !checks.is_empty() && diagnostics.is_empty(),
      citation_count: checks.length(),
      matched_count: checks.filter(check => check.quote_present).length(),
      diagnostics,
    })
  }
  let output = UrlCheckReport::{
    source_count: items.length(),
    citation_count,
    matched_count,
    items,
  }
  if json_output {
    @stdio.stdout.write(@json.to_json(output).stringify(indent=2) + "\n")
  } else {
    @stdio.stdout.write(
      "\{if matched_count == citation_count && citation_count > 0 { "PASS" } else { "FAIL" }}: \{matched_count}/\{citation_count} citations appear in \{items.length()} live web sources\n",
    )
    for item in items {
      @stdio.stdout.write(
        "  \{if item.ok { "PASS" } else { "FAIL" }} \{item.url}\n",
      )
      for diagnostic in item.diagnostics {
        @stdio.stdout.write("    [\{diagnostic}]\n")
      }
    }
  }
  if citation_count == 0 || matched_count != citation_count {
    2
  } else {
    0
  }
}

///|
async fn verify_notes_command(
  path : String,
  json_output : Bool,
  markdown_report : Bool,
) -> Int {
  let input = @fs.read_file(path).text() catch {
    _ => {
      @stdio.stderr.write("Cannot read input file: \{path}\n")
      return 1
    }
  }
  let parsed = if markdown_report {
    @tracecite.parse_markdown_report(input)
  } else {
    @tracecite.parse_citation_notes(input)
  }
  if !parsed.diagnostics.is_empty() {
    if json_output {
      @stdio.stdout.write(
        @json.to_json(CitationInputErrors::{ diagnostics: parsed.diagnostics, }).stringify(
          indent=2,
        ) +
        "\n",
      )
    } else {
      @stdio.stdout.write(
        if markdown_report {
          "Invalid Markdown citation blocks\n"
        } else {
          "Invalid citation note input\n"
        },
      )
      for diagnostic in parsed.diagnostics {
        @stdio.stdout.write(
          "  \{path}:\{diagnostic.line} [\{diagnostic.code}] \{diagnostic.message}\n",
        )
      }
    }
    return 1
  }
  let items : Array[UrlCheckItem] = []
  let fetched : Map[String, RemoteFetch] = Map([])
  let mut source_count = 0
  let mut matched_count = 0
  for note in parsed.notes {
    let result = match fetched.get(note.url) {
      Some(result) => result
      None => {
        let result = fetch_public_text(note.url)
        fetched.set(note.url, result)
        source_count = source_count + 1
        result
      }
    }
    let diagnostics : Array[String] = []
    let matched = result.ok &&
      @tracecite.quote_appears_in_text(result.text, note.quote)
    if !result.ok {
      diagnostics.push(result.error_code.unwrap_or("SOURCE_UNAVAILABLE"))
    } else if matched {
      matched_count = matched_count + 1
    } else {
      diagnostics.push("QUOTE_NOT_IN_LIVE_SOURCE")
    }
    items.push({
      index: note.line,
      url: note.url,
      ok: matched,
      citation_count: 1,
      matched_count: if matched {
        1
      } else {
        0
      },
      diagnostics,
    })
  }
  let output = UrlCheckReport::{
    source_count,
    citation_count: items.length(),
    matched_count,
    items,
  }
  if json_output {
    @stdio.stdout.write(@json.to_json(output).stringify(indent=2) + "\n")
  } else {
    @stdio.stdout.write(
      "\{if matched_count == items.length() { "PASS" } else { "FAIL" }}: \{matched_count}/\{items.length()} quotes appear in \{source_count} live web \{if source_count == 1 { "source" } else { "sources" }}\n",
    )
    for item in items {
      @stdio.stdout.write(
        "  \{if markdown_report { path + ":" } else { "line " }}\{item.index} \{if item.ok { "PASS" } else { "FAIL" }} \{item.url}\n",
      )
      for diagnostic in item.diagnostics {
        @stdio.stdout.write("    [\{diagnostic}]\n")
      }
    }
  }
  if matched_count != items.length() {
    2
  } else {
    0
  }
}

///|
async fn fetch_public_text(raw_url : String) -> RemoteFetch {
  @async.with_timeout(20_000, () => fetch_public_text_inner(raw_url)) catch {
    _ => remote_failure("REQUEST_TIMEOUT")
  }
}

///|
async fn fetch_public_text_inner(raw_url : String) -> RemoteFetch {
  let mut current = match parse_remote_url(raw_url) {
    Some(url) => url
    None => return remote_failure("INVALID_OR_BLOCKED_URL")
  }
  for _ in 0..<6 {
    if check_public_target(current) is Some(error_code) {
      return remote_failure(error_code)
    }
    let headers : @http.Headers = Map([])
    headers["Accept"] = "text/html,application/xhtml+xml,text/plain,application/json;q=0.8,*/*;q=0.1"
    headers["User-Agent"] = "TraceCite/0.4 (source verification)"
    let (response, client) = @http.get_stream(current.full, headers~) catch {
      _ => return remote_failure("HTTP_REQUEST_FAILED")
    }
    defer client.close()
    if response.code is (301 | 302 | 303 | 307 | 308) {
      let location = response.headers.get("Location")
      match location {
        None => return remote_failure("REDIRECT_WITHOUT_LOCATION")
        Some(location) => {
          let next_url = resolve_redirect(current, location)
          let next = match parse_remote_url(next_url) {
            Some(url) => url
            None => return remote_failure("INVALID_REDIRECT_TARGET")
          }
          if current.scheme == "https" && next.scheme != "https" {
            return remote_failure("HTTPS_DOWNGRADE_REDIRECT")
          }
          current = next
          continue
        }
      }
    }
    if response.code < 200 || response.code >= 300 {
      return remote_failure("HTTP_STATUS_\{response.code}")
    }
    if response.headers.get("Content-Length") is Some(length_text) {
      let length = @string.parse_int(length_text) catch { _ => -1 }
      match length {
        length if length > 2 * 1024 * 1024 =>
          return remote_failure("SOURCE_TOO_LARGE")
        length if length < 0 => return remote_failure("INVALID_CONTENT_LENGTH")
        _ => ()
      }
    }
    let chunks : Array[Byte] = []
    let mut overflow = false
    while !overflow {
      let chunk = client.read_some(max_len=16 * 1024) catch {
        _ => return remote_failure("HTTP_BODY_READ_FAILED")
      }
      match chunk {
        None => break
        Some(chunk) =>
          if chunks.length() + chunk.length() > 2 * 1024 * 1024 {
            overflow = true
          } else {
            for byte in chunk {
              chunks.push(byte)
            }
          }
      }
    }
    if overflow {
      return remote_failure("SOURCE_TOO_LARGE")
    }
    let bytes = Bytes::from_array(chunks[:])
    let content_type = response.headers.get("Content-Type").unwrap_or("")
    let media_type = content_type_media_type(content_type)
    if media_type != "" &&
      !media_type.has_prefix("text/") &&
      media_type != "application/xhtml+xml" &&
      media_type != "application/json" {
      return remote_failure("UNSUPPORTED_CONTENT_TYPE")
    }
    let text = if media_type == "text/html" ||
      media_type == "application/xhtml+xml" ||
      media_type == "" {
      match
        extract_visible_html_text(bytes, content_type_charset(content_type)) {
        Some(text) => text
        None => return remote_failure("HTML_PARSE_FAILED")
      }
    } else {
      @utf8.decode(bytes) catch {
        _ => return remote_failure("SOURCE_NOT_UTF8")
      }
    }
    return { ok: true, text, error_code: None, }
  }
  remote_failure("TOO_MANY_REDIRECTS")
}

///|
fn extract_visible_html_text(bytes : Bytes, encoding : String?) -> String? {
  let parsed = match encoding {
    Some(encoding) =>
      @html_parser.parse_bytes(bytes[:], encoding~, sanitize=true) catch {
        _ => return None
      }
    None =>
      @html_parser.parse_bytes(bytes[:], sanitize=true) catch {
        _ => return None
      }
  }
  Some(parsed.to_text(separator=" ", strip=true, separator_blocks_only=true))
}

///|
fn remote_failure(code : String) -> RemoteFetch {
  { ok: false, text: "", error_code: Some(code), }
}

///|
fn content_type_media_type(content_type : String) -> String {
  match content_type.split_once(";") {
    Some((media_type, _)) => media_type.trim().to_lower().to_owned()
    None => content_type.trim().to_lower().to_owned()
  }
}

///|
fn content_type_charset(content_type : String) -> String? {
  let lower = content_type.to_lower()
  match lower.split_once("charset=") {
    Some((_, charset_and_more)) => {
      let charset = match charset_and_more.split_once(";") {
        Some((charset, _)) => charset
        None => charset_and_more
      }
      let charset = charset.trim()
      let charset = charset.strip_prefix("\"").unwrap_or(charset)
      let charset = charset.strip_suffix("\"").unwrap_or(charset)
      if charset == "" {
        None
      } else {
        Some(charset.to_owned())
      }
    }
    None => None
  }
}

///|
fn parse_remote_url(raw_url : String) -> RemoteUrl? {
  let raw = raw_url.trim().to_owned()
  let lower = raw.to_lower()
  let (scheme, remainder) = if lower.has_prefix("https://") {
    ("https", raw[8:])
  } else if lower.has_prefix("http://") {
    ("http", raw[7:])
  } else {
    return None
  }
  if raw.contains("\\") ||
    raw.contains(" ") ||
    raw.contains("\r") ||
    raw.contains("\n") {
    return None
  }
  let mut authority_end = remainder.length()
  for delimiter in ["/", "?", "#"] {
    match remainder.find(delimiter) {
      Some(index) if index < authority_end => authority_end = index
      _ => ()
    }
  }
  let authority = remainder[:authority_end].to_owned()
  if authority == "" ||
    authority.contains("@") ||
    authority.contains("%") ||
    authority.contains("[") ||
    authority.contains("]") {
    return None
  }
  let host_and_port = authority.split(":").to_array()
  if host_and_port.length() > 2 {
    return None
  }
  let host = host_and_port[0].to_lower().to_owned()
  let expected_port = if scheme == "https" { 443 } else { 80 }
  if host_and_port.length() == 2 {
    let port = @string.parse_int(host_and_port[1]) catch { _ => return None }
    if port != expected_port {
      return None
    }
  }
  if !valid_dns_host(host) {
    return None
  }
  let remainder_path = remainder[authority_end:].to_owned()
  let without_fragment = match remainder_path.split_once("#") {
    Some((before, _)) => before.to_owned()
    None => remainder_path
  }
  let path = if without_fragment == "" {
    "/"
  } else if without_fragment.has_prefix("?") {
    "/" + without_fragment
  } else {
    without_fragment
  }
  Some(RemoteUrl::{
    scheme,
    host,
    port: expected_port,
    path,
    full: scheme + "://" + host + path,
  })
}

///|
fn valid_dns_host(host : String) -> Bool {
  if host == "" ||
    host.has_prefix(".") ||
    host.has_suffix(".") ||
    host.has_prefix("-") ||
    host.has_suffix("-") ||
    host == "localhost" ||
    host.has_suffix(".localhost") ||
    host.has_suffix(".local") ||
    host.has_suffix(".internal") ||
    host.has_suffix(".test") ||
    host.has_suffix(".invalid") ||
    host.has_suffix(".example") ||
    host.contains("..") {
    return false
  }
  let mut numeric_or_dot = true
  let mut previous_dot = false
  for ch in host.iter() {
    let digit = ch >= '0' && ch <= '9'
    let letter = ch >= 'a' && ch <= 'z'
    if !(digit || letter || ch == '-' || ch == '.') {
      return false
    }
    if !(digit || ch == '.') {
      numeric_or_dot = false
    }
    if ch == '.' {
      if previous_dot {
        return false
      }
      previous_dot = true
    } else {
      if previous_dot && ch == '-' {
        return false
      }
      if ch == '-' && (previous_dot || host.has_prefix("-")) {
        return false
      }
      previous_dot = false
    }
  }
  if previous_dot || host.contains(".-") || host.contains("-.") {
    return false
  }
  if numeric_or_dot {
    let octets = host.split(".").to_array()
    if octets.length() != 4 {
      return false
    }
    for octet in octets {
      if octet == "" || (octet.length() > 1 && octet.has_prefix("0")) {
        return false
      }
      let value = @string.parse_int(octet) catch { _ => return false }
      if value < 0 || value > 255 {
        return false
      }
    }
    if !is_public_ipv4_host(host) {
      return false
    }
  }
  true
}

///|
fn is_public_ipv4_host(host : String) -> Bool {
  let parts = host.split(".").to_array()
  if parts.length() != 4 {
    return false
  }
  let octets : Array[Int] = []
  for part in parts {
    octets.push(@string.parse_int(part) catch { _ => return false })
  }
  is_public_ipv4_octets(octets[0], octets[1], octets[2])
}

///|
fn is_public_ipv4_octets(a : Int, b : Int, c : Int) -> Bool {
  !(a == 0 ||
  a == 10 ||
  a == 127 ||
  (a == 100 && b >= 64 && b <= 127) ||
  (a == 169 && b == 254) ||
  (a == 172 && b >= 16 && b <= 31) ||
  (a == 192 && (b == 0 || b == 168)) ||
  (a == 192 && b == 0 && c == 2) ||
  (a == 192 && b == 88 && c == 99) ||
  (a == 198 && (b == 18 || b == 19 || (b == 51 && c == 100))) ||
  (a == 203 && b == 0 && c == 113) ||
  a >= 224)
}

///|
async fn check_public_target(url : RemoteUrl) -> String? {
  if !valid_dns_host(url.host) {
    return Some("URL_BLOCKED")
  }
  let mut resolved = false
  let v4 : @socket.Addr? = Some(
    @socket.Addr::resolve(url.host, port=url.port, protocol=@socket.OnlyV4),
  ) catch {
    _ => None
  }
  match v4 {
    Some(address) => {
      resolved = true
      if address.is_multicast() ||
        !is_allowed_resolved_ipv4(
          url.scheme,
          ((address.ip() >> 24) & 255).reinterpret_as_int(),
          ((address.ip() >> 16) & 255).reinterpret_as_int(),
          ((address.ip() >> 8) & 255).reinterpret_as_int(),
        ) {
        return Some("URL_BLOCKED")
      }
    }
    None => ()
  }
  let v6 : @socket.Addr? = Some(
    @socket.Addr::resolve(url.host, port=url.port, protocol=@socket.OnlyV6),
  ) catch {
    _ => None
  }
  match v6 {
    Some(address) => {
      resolved = true
      if address.is_multicast() || !is_public_ipv6_address(address.to_string()) {
        return Some("URL_BLOCKED")
      }
    }
    None => ()
  }
  if resolved {
    None
  } else {
    Some("HOST_UNRESOLVED")
  }
}

///|
fn is_allowed_resolved_ipv4(scheme : String, a : Int, b : Int, c : Int) -> Bool {
  is_public_ipv4_octets(a, b, c) ||
  (scheme == "https" && a == 198 && b >= 18 && b <= 19)
}

///|
fn is_public_ipv6_address(rendered : String) -> Bool {
  let address = rendered.to_lower()
  (address.has_prefix("[2") || address.has_prefix("[3")) &&
  !address.has_prefix("[2001:db8:") &&
  !address.has_prefix("[2001::") &&
  !address.has_prefix("[2001:0") &&
  !address.has_prefix("[2001:20") &&
  !address.has_prefix("[2002:") &&
  !address.has_prefix("[3fff:")
}

///|
fn resolve_redirect(current : RemoteUrl, location : String) -> String {
  let location = location.trim().to_owned()
  let lower_location = location.to_lower()
  if lower_location.has_prefix("http://") ||
    lower_location.has_prefix("https://") {
    return location
  }
  if location.has_prefix("//") {
    return current.scheme + ":" + location
  }
  let origin = current.scheme + "://" + current.host
  if location.has_prefix("/") {
    return origin + location
  }
  let path = match current.path.split_once("?") {
    Some((before, _)) => before.to_owned()
    None => current.path
  }
  if location.has_prefix("?") {
    return origin + path + location
  }
  let directory = match path.rev_find("/") {
    Some(index) => path[:index + 1].to_owned()
    None => "/"
  }
  origin + directory + location
}
