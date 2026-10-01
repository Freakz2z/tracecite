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
  for heading in document_source_headings(lines) {
    let index = heading.start
    let level = heading.level
    if section_start is Some(first) && level <= section_level {
      return { ok: true, text: lines[first:index].join("\n"), code: "", }
    }
    let title = heading.title
    let slug = markdown_heading_slug(title)
    let mut count = counts.get(slug).unwrap_or(0)
    let mut unique = slug
    while counts.get(unique) is Some(_) {
      count = count + 1
      unique = "\{slug}-\{count}"
    }
    counts.set(slug, count)
    counts.set(unique, 0)
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
priv struct DocumentHeading {
  start : Int
  level : Int
  title : String
}

///|
fn document_source_headings(lines : Array[String]) -> Array[DocumentHeading] {
  let headings : Array[DocumentHeading] = []
  let paragraph : Array[String] = []
  let mut paragraph_start = 0
  let mut fence : (Char, Int)? = None
  let mut comment = false
  let mut html_end : String? = None
  let mut container = false
  for index = 0; index < lines.length(); index = index + 1 {
    if html_end is Some(marker) {
      if marker == "" {
        let (_, next_comment) = document_visible_line(lines[index], comment)
        comment = next_comment
      }
      if (marker == "" && lines[index].trim() == "") ||
        (marker != "" && lines[index].to_lower().contains(marker)) {
        html_end = None
      }
      continue
    }
    let (visible, next_comment) = if fence is None {
      document_visible_line(lines[index], comment)
    } else {
      (lines[index], comment)
    }
    comment = next_comment
    let line = visible.trim()
    if fence is Some((ch, size)) {
      if document_fence(line) is Some((closing, count, info)) &&
        closing == ch &&
        count >= size &&
        info == "" {
        fence = None
      }
      continue
    }
    if document_fence(line) is Some((ch, size, _)) {
      fence = Some((ch, size))
      paragraph.clear()
      container = false
      continue
    }
    let chars = visible.to_array()
    let mut indent = 0
    while indent < chars.length() && chars[indent] == ' ' {
      indent = indent + 1
    }
    if indent > 3 ||
      (indent < chars.length() && chars[indent] == '\t') ||
      line == "" {
      paragraph.clear()
      if line == "" {
        container = false
      }
      continue
    }
    if document_heading_html_end(line.to_owned(), paragraph.is_empty())
      is Some(marker) {
      if marker != "" {
        comment = false
      }
      if marker == "" || !line.to_owned().to_lower().contains(marker) {
        html_end = Some(marker)
      }
      paragraph.clear()
      continue
    }
    let title_chars = line.to_owned().to_array()
    let mut level = 0
    while level < title_chars.length() && title_chars[level] == '#' {
      level = level + 1
    }
    if level >= 1 &&
      level <= 6 &&
      (
        level == title_chars.length() ||
        title_chars[level] == ' ' ||
        title_chars[level] == '\t'
      ) {
      let mut end = title_chars.length()
      while end > level && title_chars[end - 1] == '#' {
        end = end - 1
      }
      if end < title_chars.length() &&
        end > level &&
        title_chars[end - 1] != ' ' &&
        title_chars[end - 1] != '\t' {
        end = title_chars.length()
      }
      headings.push({
        start: index,
        level,
        title: String::from_array(title_chars[level:end]).trim().to_owned(),
      })
      paragraph.clear()
      container = false
      continue
    }
    let underline = if title_chars.all(ch => ch == '=') {
      Some(1)
    } else if title_chars.all(ch => ch == '-') {
      Some(2)
    } else {
      None
    }
    if underline is Some(level) && !paragraph.is_empty() && !container {
      headings.push({
        start: paragraph_start,
        level,
        title: paragraph.join(" "),
      })
      paragraph.clear()
      continue
    }
    if document_heading_block_line(line.to_owned()) {
      paragraph.clear()
      if !document_heading_thematic_break(line.to_owned()) &&
        document_definition(line) is None {
        container = true
      }
      continue
    }
    if container {
      continue
    }
    if paragraph.is_empty() {
      paragraph_start = index
    }
    paragraph.push(line.to_owned())
  }
  headings
}

///|
fn document_heading_block_line(line : String) -> Bool {
  if document_definition(line[:]) is Some(_) ||
    line.has_prefix(">") ||
    line == "-" ||
    line == "*" ||
    line == "+" ||
    ["- ", "+ ", "* ", "-\t", "+\t", "*\t"].any(prefix => {
      line.has_prefix(prefix)
    }) {
    return true
  }
  let chars = line.to_array()
  let mut digits = 0
  while digits < chars.length() && chars[digits] >= '0' && chars[digits] <= '9' {
    digits = digits + 1
  }
  if digits > 0 &&
    digits <= 9 &&
    digits + 1 < chars.length() &&
    (chars[digits] == '.' || chars[digits] == ')') &&
    (chars[digits + 1] == ' ' || chars[digits + 1] == '\t') {
    return true
  }
  document_heading_thematic_break(line)
}

///|
fn document_heading_thematic_break(line : String) -> Bool {
  let chars = line.to_array()
  for marker in ['-', '*', '_'] {
    if chars.filter(ch => ch == marker).length() >= 3 &&
      chars.all(ch => ch == marker || ch == ' ' || ch == '\t') {
      return true
    }
  }
  false
}

///|
fn document_heading_html_end(line : String, paragraph_empty : Bool) -> String? {
  let lower = line.to_lower()
  if !lower.has_prefix("<") {
    return None
  }
  if lower.has_prefix("<?") {
    return Some("?>")
  }
  if lower.has_prefix("<![cdata[") {
    return Some("]]>")
  }
  if lower.has_prefix("<!") {
    return Some(">")
  }
  let tail = lower.strip_prefix("</").unwrap_or(lower[1:]).to_owned().to_array()
  let mut end = 0
  while end < tail.length() &&
        (
          (tail[end] >= 'a' && tail[end] <= 'z') ||
          (tail[end] >= '0' && tail[end] <= '9') ||
          tail[end] == '-'
        ) {
    end = end + 1
  }
  if end == 0 ||
    end == tail.length() ||
    ![' ', '\t', '>', '/'].contains(tail[end]) {
    return None
  }
  let tag = String::from_array(tail[:end])
  if ["script", "pre", "style", "textarea"].contains(tag) &&
    !lower.has_prefix("</") {
    return Some("</" + tag + ">")
  }
  if [
      "address", "article", "aside", "base", "basefont", "blockquote", "body", "caption",
      "center", "col", "colgroup", "dd", "details", "dialog", "dir", "div", "dl",
      "dt", "fieldset", "figcaption", "figure", "footer", "form", "frame", "frameset",
      "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "html", "iframe",
      "legend", "li", "link", "main", "menu", "menuitem", "nav", "noframes", "ol",
      "optgroup", "option", "p", "param", "search", "section", "summary", "table",
      "tbody", "td", "tfoot", "th", "thead", "title", "tr", "track", "ul",
    ].contains(tag) {
    return Some("")
  }
  if paragraph_empty &&
    document_html_tags(line[:]).any(tag => {
      tag.start == 0 && tag.end == line.to_array().length()
    }) {
    return Some("")
  }
  None
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
  let chars = title.to_array()
  let hidden : Array[(Int, Int)] = []
  for tag in document_html_tags(title[:]) {
    hidden.push((tag.start, tag.end))
  }
  for link in document_links(title[:], Map([])) {
    let mut end = link.start + 1
    let mut depth = 1
    while end < link.end && depth > 0 {
      if !document_is_escaped(chars, end) {
        if chars[end] == '[' {
          depth = depth + 1
        } else if chars[end] == ']' {
          depth = depth - 1
        }
      }
      end = end + 1
    }
    if depth == 0 {
      hidden.push((end, link.end))
    }
  }
  let output = StringBuilder()
  for index = 0; index < chars.length(); index = index + 1 {
    if !hidden.any(range => index >= range.0 && index < range.1) {
      output.write_char(chars[index])
    }
  }
  let rendered = output.to_string().to_lower()
  output.reset()
  for ch in rendered.iter() {
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
