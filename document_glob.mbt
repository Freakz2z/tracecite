///|
/// Wildcards operate on root-relative paths. ** is a complete path segment;
/// * and ? never cross a slash. Literal path behavior remains unchanged.
pub fn document_path_has_glob(path : String) -> Bool {
  path.contains("*") || path.contains("?")
}

///|
pub fn normalize_document_path_pattern(path : String) -> String? {
  if valid_document_path_pattern(path) {
    Some(normalize_document_config_path(path))
  } else {
    None
  }
}

///|
pub fn valid_document_path_pattern(path : String) -> Bool {
  if !valid_document_config_path(path) {
    return false
  }
  if document_path_has_glob(path) {
    for part in path.split("/") {
      if part == ".." || (part.contains("**") && part != "**") {
        return false
      }
    }
  }
  true
}

///|
/// Match a glob, or a literal file/directory and its descendants. No filesystem
/// access is performed; callers enforce canonical workspace boundaries.
pub fn document_path_pattern_matches(pattern : String, path : String) -> Bool {
  if !valid_document_path_pattern(pattern) || !valid_document_config_path(path) {
    return false
  }
  let pattern = normalize_document_config_path(pattern)
  let path = normalize_document_config_path(path)
  if !document_path_has_glob(pattern) {
    return pattern == "." || path == pattern || path.has_prefix(pattern + "/")
  }
  let parts = pattern.split("/").to_array()
  let names = path.split("/").to_array()
  let mut previous = Array::make(names.length() + 1, false)
  previous[0] = true
  for part in parts {
    let next = Array::make(names.length() + 1, false)
    if part == "**" {
      next[0] = previous[0]
      for index = 1; index <= names.length(); index = index + 1 {
        next[index] = previous[index] || next[index - 1]
      }
    } else {
      for index = 1; index <= names.length(); index = index + 1 {
        next[index] = previous[index - 1] &&
          document_glob_segment(part.to_owned(), names[index - 1].to_owned())
      }
    }
    previous = next
  }
  previous[names.length()]
}

///|
fn document_glob_segment(pattern : String, name : String) -> Bool {
  let chars = name.to_array()
  let mut previous = Array::make(chars.length() + 1, false)
  previous[0] = true
  for ch in pattern.iter() {
    let next = Array::make(chars.length() + 1, false)
    next[0] = ch == '*' && previous[0]
    for index = 1; index <= chars.length(); index = index + 1 {
      next[index] = if ch == '*' {
        previous[index] || next[index - 1]
      } else {
        previous[index - 1] && (ch == '?' || ch == chars[index - 1])
      }
    }
    previous = next
  }
  previous[chars.length()]
}
