///|
pub(all) struct SelectedSource {
  ok : Bool
  text : String
  code : String
} derive(ToJson)

///|
pub extend SelectedSource with ToJson::{to_json}

///|
/// Select the whole source, a #Lx-Ly range, a Markdown heading section, or
/// #region:name between ANCHOR: name / ANCHOR_END: name comments.
pub fn select_document_source(
  content : String,
  fragment : String,
) -> SelectedSource {
  let text = content.replace_all(old="\r\n", new="\n")
  if fragment == "" {
    return { ok: true, text, code: "", }
  }
  let lines = text.split("\n").map(line => line.to_owned()).to_array()
  if fragment.has_prefix("L") {
    let range = fragment[1:].split_once("-L")
    let start = @string.parse_int(
      match range {
        Some((first, _)) => first
        None => fragment[1:]
      },
    ) catch {
      _ => -1
    }
    let end = match range {
      Some((_, last)) => @string.parse_int(last) catch { _ => -1 }
      None => start
    }
    // A trailing newline is not an extra addressable source line.
    let count = if text.has_suffix("\n") {
      lines.length() - 1
    } else {
      lines.length()
    }
    if start < 1 || end < start || end > count {
      return { ok: false, text: "", code: "INVALID_LINE_RANGE", }
    }
    return { ok: true, text: lines[start - 1:end].join("\n"), code: "", }
  }
  if fragment.strip_prefix("region:") is Some(region) {
    let mut start : Int? = None
    for index = 0; index < lines.length(); index = index + 1 {
      if region_marker(lines[index], "ANCHOR:") == Some(region.to_owned()) {
        if start is Some(_) {
          return { ok: false, text: "", code: "AMBIGUOUS_REGION", }
        }
        start = Some(index + 1)
      }
      if region_marker(lines[index], "ANCHOR_END:") == Some(region.to_owned()) &&
        start is Some(first) {
        return { ok: true, text: lines[first:index].join("\n"), code: "", }
      }
    }
    return { ok: false, text: "", code: "REGION_NOT_FOUND", }
  }
  let counts : Map[String, Int] = Map([])
  let mut section_start : Int? = None
  let mut section_level = 0
  let mut active_fence : (Char, Int)? = None
  for index = 0; index < lines.length(); index = index + 1 {
    let line = lines[index].trim()
    if active_fence is Some((ch, size)) {
      if document_fence(line) is Some((closing, count, info)) &&
        closing == ch &&
        count >= size &&
        info == "" {
        active_fence = None
      }
      continue
    }
    if document_fence(line) is Some((ch, size, _)) {
      active_fence = Some((ch, size))
      continue
    }
    let chars = line.to_owned().to_array()
    let mut level = 0
    while level < chars.length() && chars[level] == '#' {
      level = level + 1
    }
    if level < 1 || level > 6 || level >= chars.length() || chars[level] != ' ' {
      continue
    }
    if section_start is Some(first) && level <= section_level {
      return { ok: true, text: lines[first:index].join("\n"), code: "", }
    }
    let slug = markdown_heading_slug(String::from_array(chars[level + 1:]))
    let count = counts.get(slug).unwrap_or(0)
    counts.set(slug, count + 1)
    let unique = if count == 0 { slug } else { "\{slug}-\{count}" }
    if unique == fragment {
      section_start = Some(index)
      section_level = level
    }
  }
  match section_start {
    Some(first) => { ok: true, text: lines[first:].join("\n"), code: "", }
    None => { ok: false, text: "", code: "ANCHOR_NOT_FOUND", }
  }
}

///|
fn region_marker(line : String, marker : String) -> String? {
  match line.split_once(marker) {
    Some((_, tail)) => {
      let value = tail.trim().split(" ").next().unwrap_or("").to_owned()
      if value == "" {
        None
      } else {
        Some(value)
      }
    }
    None => None
  }
}

///|
pub fn markdown_heading_slug(title : String) -> String {
  let output = StringBuilder()
  for ch in title.to_lower().iter() {
    if ch == ' ' || ch == '\t' {
      output.write_char('-')
    } else if (ch >= 'a' && ch <= 'z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-' ||
      ch == '_' {
      output.write_char(ch)
    } else if ch >= '\u{80}' &&
      !"。，：；！？、（）【】《》“”‘’".contains(
        ch.to_string(),
      ) {
      output.write_char(ch)
    }
  }
  output.to_string()
}

///|
/// Code snippets are compared by complete lines. Quotes retain the existing
/// typography/whitespace normalization. Code punctuation and indentation matter.
pub fn document_excerpt_matches(
  content : String,
  excerpt : String,
  kind : String,
) -> Bool {
  if excerpt.trim() == "" {
    return false
  }
  if kind != "snippet" {
    return quote_appears_in_text(content, excerpt)
  }
  let source = content.replace_all(old="\r\n", new="\n")
  let excerpt = excerpt.replace_all(old="\r\n", new="\n")
  ("\n" + source + "\n").contains("\n" + excerpt + "\n")
}

///|
/// A bounded candidate excerpt for review, not an automatic correction.
pub fn document_source_context(
  content : String,
  excerpt : String,
  kind : String,
) -> String {
  if kind == "snippet" && document_excerpt_matches(content, excerpt, kind) {
    return excerpt.replace_all(old="\r\n", new="\n")
  }
  if kind == "quote" {
    let text = normalize_web_text(strip_quote_marks(content))
    let quote = normalize_web_text(strip_quote_marks(excerpt))
    let without_markers = quote
      .replace_all(old="(…)", new="…")
      .replace_all(old="(...)", new="…")
      .replace_all(old="...", new="…")
    let first = without_markers
      .split("…")
      .next()
      .unwrap_or(without_markers[:])
      .trim()
    if text.split_once(first) is Some((before, after)) && first != "" {
      let prefix = before.to_owned().to_array()
      let suffix = after.to_owned().to_array()
      let start = if prefix.length() > 100 { prefix.length() - 100 } else { 0 }
      let end = if suffix.length() > 100 { 100 } else { suffix.length() }
      return String::from_array(prefix[start:]) +
        first.to_owned() +
        String::from_array(suffix[:end])
    }
    return bounded_document_text(text)
  }
  let lines = content.replace_all(old="\r\n", new="\n").split("\n").to_array()
  let expected_lines = excerpt.split("\n").to_array()
  let first = expected_lines[0].to_owned().to_array()
  let mut best = 0
  let mut best_score = -1
  for index = 0; index < lines.length(); index = index + 1 {
    let actual = lines[index].to_owned().to_array()
    let mut score = 0
    while score < first.length() &&
          score < actual.length() &&
          first[score] == actual[score] {
      score = score + 1
    }
    if score > best_score {
      best = index
      best_score = score
    }
  }
  let end = if best + expected_lines.length() < lines.length() {
    best + expected_lines.length()
  } else {
    lines.length()
  }
  bounded_document_text(lines[best:end].join("\n"))
}

///|
pub fn bounded_document_text(text : String) -> String {
  let chars = text.to_array()
  if chars.length() <= 1600 {
    text
  } else {
    String::from_array(chars[:1600]) + "\n…"
  }
}

///|
/// Portable baseline identities omit document line numbers, so moving a
/// paragraph does not invalidate its unchanged dependency.
pub(all) struct DocumentSnapshotEntry {
  document : String
  source : String
  kind : String
  excerpt : String?
  observed : String
} derive(ToJson, @json.FromJson)

///|
pub extend DocumentSnapshotEntry with ToJson::{to_json}

///|
pub extend DocumentSnapshotEntry with @json.FromJson::{from_json}

///|
pub(all) struct DocumentSnapshot {
  version : Int
  entries : Array[DocumentSnapshotEntry]
} derive(ToJson, @json.FromJson)

///|
pub extend DocumentSnapshot with ToJson::{to_json}

///|
pub extend DocumentSnapshot with @json.FromJson::{from_json}
