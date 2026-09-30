///|
test "environment proxy selection respects schemes and lowercase precedence" {
  let https = parse_remote_url("https://example.org/").unwrap()
  let http = parse_remote_url("http://example.org/").unwrap()
  let variables : Map[String, String] = {
    "HTTPS_PROXY": "http://upper-proxy:8080",
    "https_proxy": "http://lower-proxy:8080",
    "HTTP_PROXY": "http://plain-proxy:8080",
  }
  let lookup = name => variables.get(name)
  assert_eq(remote_proxy(https, lookup), Some("http://lower-proxy:8080"))
  assert_eq(remote_proxy(http, lookup), Some("http://plain-proxy:8080"))
  variables["https_proxy"] = " "
  assert_eq(remote_proxy(https, lookup), Some("http://upper-proxy:8080"))
  variables["NO_PROXY"] = ".example.org"
  assert_eq(remote_proxy(https, lookup), None)
  assert_eq(remote_proxy(https, _ => None), None)
}

///|
test "NO_PROXY matches domain boundaries and optional ports" {
  let url = parse_remote_url("https://sub.example.org/").unwrap()
  assert_true(proxy_bypassed(url, "other.org, .example.org:443"))
  assert_true(proxy_bypassed(url, "example.org"))
  assert_true(proxy_bypassed(url, "SUB.EXAMPLE.ORG"))
  assert_true(proxy_bypassed(url, "*"))
  assert_false(proxy_bypassed(url, "example.org:80"))
  assert_false(proxy_bypassed(url, "ample.org"))
  assert_false(proxy_bypassed(url, "example.org:invalid"))
  assert_false(proxy_bypassed(url, ""))
}

///|
test "proxy endpoints accept private hosts and reject malformed or credentialed URLs" {
  assert_eq(
    parse_proxy_url("http://127.0.0.1:8080/"),
    Some("http://127.0.0.1:8080"),
  )
  assert_eq(
    parse_proxy_url("https://proxy.example:8443"),
    Some("https://proxy.example:8443"),
  )
  assert_eq(parse_proxy_url("http://localhost"), Some("http://localhost"))
  for
    invalid in [
      "socks5://localhost:1080", "http://user:password@localhost:8080", "http://localhost/path",
      "http://localhost?query", "http://localhost#fragment", "http://localhost:0",
      "http://localhost:65536", "http://localhost:", "http://localhost:+80", "http://localhost: 80",
      "http://local host", "http://", "http://localhost\r\nInjected: value",
    ] {
    assert_eq(parse_proxy_url(invalid), None)
  }
}

///|
async test "fetch uses CONNECT proxy and reads the tunneled source response" {
  @async.with_timeout(5_000, () => {
    @async.with_task_group() <| group => {
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      defer server.close()
      let proxy_uri = "http://127.0.0.1:\{server.addr.port()}"
      group.spawn_bg() <| () => {
        let (socket, _) = server.accept()
        let connection = @http.ServerConnection::new(socket)
        defer connection.close()
        let request = connection.read_request()
        assert_true(request.meth is Connect)
        assert_eq(request.path, "93.184.216.34:80")
        connection..send_response(200, "OK").end_response()
        let request = connection.read_request()
        assert_true(request.meth is Get)
        assert_eq(request.path, "/source")
        let headers : @http.Headers = { "Content-Type": "text/plain" }
        connection
        ..send_response(200, "OK", extra_headers=headers)
        ..write("verified source text")
        .end_response()
      }
      let result = fetch_public_text_inner("http://93.184.216.34/source", get_env=name => {
        if name == "http_proxy" {
          Some(proxy_uri)
        } else {
          None
        }
      })
      assert_true(result.ok)
      assert_eq(result.text, "verified source text")
    }
  })
}

///|
async test "proxy configuration cannot bypass source URL policy" {
  let result = fetch_public_text_inner("http://127.0.0.1/source", get_env=_ => {
    Some("http://127.0.0.1:1")
  })
  assert_false(result.ok)
  assert_eq(result.error_code, Some("INVALID_OR_BLOCKED_URL"))
  let result = fetch_public_text_inner("https://93.184.216.34/source", get_env=name => {
    if name == "https_proxy" {
      Some("socks5://localhost:1080")
    } else {
      None
    }
  })
  assert_eq(result.error_code, Some("INVALID_PROXY_URL"))
}
