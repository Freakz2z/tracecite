///|
/// Recognize only an empty standalone <a id=...></a> on one line. The caller
/// excludes comments, code, and HTML blocks using the same scan as headings.
fn document_standalone_anchor_id(line : String) -> String? {
  let chars = line.to_array()
  let tags = document_html_tags(line[:]).filter(tag => tag.source == "")
  if tags.length() != 2 ||
    tags[0].start != 0 ||
    tags[1].end != chars.length() ||
    String::from_array(chars[tags[1].start:]).to_lower() != "</a>" ||
    String::from_array(chars[tags[0].end:tags[1].start]).trim() != "" ||
    chars.length() < 4 ||
    (chars[1] != 'a' && chars[1] != 'A') ||
    (chars[2] != ' ' && chars[2] != '\t') {
    return None
  }
  let end = tags[0].end - 1
  let mut index = 2
  while index < end {
    while index < end && (chars[index] == ' ' || chars[index] == '\t') {
      index += 1
    }
    let first = index
    while index < end &&
          chars[index] != '=' &&
          chars[index] != ' ' &&
          chars[index] != '\t' {
      index += 1
    }
    let name = String::from_array(chars[first:index]).to_lower()
    while index < end && (chars[index] == ' ' || chars[index] == '\t') {
      index += 1
    }
    if index >= end {
      break
    }
    if chars[index] != '=' {
      continue
    }
    index += 1
    while index < end && (chars[index] == ' ' || chars[index] == '\t') {
      index += 1
    }
    if index >= end {
      return None
    }
    let quote = if chars[index] == '"' || chars[index] == '\'' {
      Some(chars[index])
    } else {
      None
    }
    if quote is Some(_) {
      index += 1
    }
    let first = index
    while index < end {
      if quote is Some(mark) {
        if chars[index] == mark {
          break
        }
      } else if chars[index] == ' ' || chars[index] == '\t' {
        break
      }
      index += 1
    }
    if name == "id" {
      let value = String::from_array(chars[first:index])
      if value == "" ||
        value.contains("&#") ||
        value.iter().any(ch => ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
        return None
      }
      return Some(
        value
        .replace_all(old="&quot;", new="\"")
        .replace_all(old="&apos;", new="'")
        .replace_all(old="&lt;", new="<")
        .replace_all(old="&gt;", new=">")
        .replace_all(old="&amp;", new="&"),
      )
    }
    if quote is Some(_) {
      index += 1
    }
  }
  None
}
