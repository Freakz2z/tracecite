///|
test "remote URL parser keeps query and removes fragment" {
  let parsed = parse_remote_url("HTTPS://EXAMPLE.org/path?q=42#section")
  assert_true(parsed is Some(_))
  match parsed {
    Some(url) => {
      assert_eq(url.host, "example.org")
      assert_eq(url.path, "/path?q=42")
      assert_eq(url.full, "https://example.org/path?q=42")
    }
    None => fail("expected valid public URL")
  }
}

///|
test "remote URL parser blocks local, credentialed, and unusual port URLs" {
  assert_true(parse_remote_url("file:///etc/passwd") is None)
  assert_true(parse_remote_url("http://127.0.0.1/page") is None)
  assert_true(parse_remote_url("http://169.254.169.254/latest") is None)
  assert_true(parse_remote_url("https://198.18.0.56/page") is None)
  assert_true(parse_remote_url("http://localhost/page") is None)
  assert_true(parse_remote_url("https://user@example.org/page") is None)
  assert_true(parse_remote_url("http://example.org:8080/page") is None)
}

///|
test "redirect target is resolved and stays subject to URL policy" {
  let current = parse_remote_url("https://example.org/a/b").unwrap_or({
    scheme: "",
    host: "",
    port: 443,
    path: "/",
    full: "",
  })
  assert_eq(resolve_redirect(current, "/next"), "https://example.org/next")
  assert_eq(
    resolve_redirect(current, "../next"),
    "https://example.org/a/../next",
  )
  assert_true(
    parse_remote_url(resolve_redirect(current, "//127.0.0.1/")) is None,
  )
}

///|
test "public address screening rejects non-public IPv4 and IPv6 ranges" {
  assert_false(is_public_ipv4_octets(127, 0, 0))
  assert_false(is_public_ipv4_octets(10, 1, 2))
  assert_false(is_public_ipv4_octets(169, 254, 1))
  assert_true(is_public_ipv4_octets(93, 184, 216))
  assert_false(is_allowed_resolved_ipv4("http", 198, 18, 0))
  assert_true(is_allowed_resolved_ipv4("https", 198, 18, 0))
  assert_false(is_public_ipv6_address("[fd00::1]:443"))
  assert_false(is_public_ipv6_address("[fe80::1]:443"))
  assert_false(is_public_ipv6_address("[2001:db8::1]:443"))
  assert_false(is_public_ipv6_address("[2001::1]:443"))
  assert_true(is_public_ipv6_address("[2606:4700::1111]:443"))
}

///|
test "HTML extraction decodes entities and omits active script text" {
  let html = @utf8.encode(
    "<p>alpha&nbsp;beta</p><p>MoonBit in <code>$HOME/.moon</code> and adds it to your <code>PATH</code>.</p><script>secret-marker</script>",
  )
  let visible = extract_visible_html_text(html).unwrap()
  assert_true(@tracecite.normalize_web_text(visible).contains("alpha beta"))
  assert_true(
    @tracecite.normalize_web_text(visible).contains(
      "MoonBit in $HOME/.moon and adds it to your PATH.",
    ),
  )
  assert_false(visible.contains("secret-marker"))
}

///|
test "HTML inline code does not create spaces inside parentheses" {
  let html = @utf8.encode(
    "<p>Some commands are module-only (for example <code>publish</code>). For those commands, run them in a specific member module directory.</p>",
  )
  let visible = extract_visible_html_text(html).unwrap()
  assert_true(
    @tracecite.normalize_web_text(visible).contains(
      "Some commands are module-only (for example publish).",
    ),
  )
}

///|
test "content type parameters do not hide the media type" {
  assert_eq(content_type_media_type("Text/HTML; charset=utf-8"), "text/html")
  assert_eq(
    content_type_media_type(" application/json ; charset=UTF-8 "),
    "application/json",
  )
}
