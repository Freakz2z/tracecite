///|
fn first_nonempty_env(
  names : Array[String],
  get_env : (String) -> String?,
) -> String? {
  for name in names {
    if get_env(name) is Some(value) && value.trim() != "" {
      return Some(value.trim().to_owned())
    }
  }
  None
}

///|
fn remote_proxy(url : RemoteUrl, get_env : (String) -> String?) -> String? {
  if first_nonempty_env(["no_proxy", "NO_PROXY"], get_env) is Some(exclusions) &&
    proxy_bypassed(url, exclusions) {
    return None
  }
  first_nonempty_env(
    if url.scheme == "https" {
      ["https_proxy", "HTTPS_PROXY"]
    } else {
      ["http_proxy", "HTTP_PROXY"]
    },
    get_env,
  )
}

///|
fn proxy_bypassed(url : RemoteUrl, exclusions : String) -> Bool {
  for entry in exclusions.split(",") {
    let entry = entry.trim().to_lower().to_owned()
    if entry == "*" {
      return true
    }
    let parts = entry.split(":").to_array()
    if parts.length() > 2 {
      continue
    }
    if parts.length() == 2 {
      let port = @string.parse_int(parts[1]) catch { _ => continue }
      if port != url.port {
        continue
      }
    }
    let host = parts[0].strip_prefix(".").unwrap_or(parts[0]).to_owned()
    if host != "" && (url.host == host || url.host.has_suffix("." + host)) {
      return true
    }
  }
  false
}

///|
/// Proxy endpoints may be private and use non-default ports. Source URLs still
/// pass the existing public-address checks before connecting through a proxy.
fn parse_proxy_url(raw : String) -> String? {
  let (scheme, authority) = if raw.has_prefix("http://") {
    ("http", raw[7:])
  } else if raw.has_prefix("https://") {
    ("https", raw[8:])
  } else {
    return None
  }
  let authority = authority.strip_suffix("/").unwrap_or(authority)
  let parts = authority.split(":").to_array()
  if parts.length() > 2 || parts[0] == "" {
    return None
  }
  for ch in parts[0].iter() {
    if !(ch is ('a'..='z' | 'A'..='Z' | '0'..='9' | '.' | '-')) {
      return None
    }
  }
  if parts.length() == 2 {
    if parts[1] == "" {
      return None
    }
    for ch in parts[1].iter() {
      if !(ch is ('0'..='9')) {
        return None
      }
    }
    let port = @string.parse_int(parts[1]) catch { _ => return None }
    if port < 1 || port > 65535 {
      return None
    }
  }
  Some(scheme + "://" + authority.to_owned())
}
