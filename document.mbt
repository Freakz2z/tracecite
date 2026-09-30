///|
/// A document dependency. Snippets preserve code exactly; quotes use text matching.
pub(all) struct DocumentReference {
  line : Int
  source : String
  kind : String
  excerpt : String?
} derive(ToJson)

///|
pub extend DocumentReference with ToJson::{to_json}

///|
pub(all) struct DocumentReferences {
  references : Array[DocumentReference]
  diagnostics : Array[Diagnostic]
  warnings : Array[Diagnostic]
  unbound_snippets : Int
} derive(ToJson)

///|
pub extend DocumentReferences with ToJson::{to_json}

///|
priv struct MarkdownLink {
  start : Int
  end : Int
  source : String
}

///|
/// Extract inline links, quoted citations, explicit quote/source blocks, and
/// fenced snippets with `source=path`. Ordinary code fences are counted, not run.
pub fn parse_document(input : String) -> DocumentReferences {
  let references : Array[DocumentReference] = []
  let diagnostics : Array[Diagnostic] = []
  let warnings : Array[Diagnostic] = []
  let lines = input.replace_all(old="\r\n", new="\n").split("\n").to_array()
  let definitions : Map[String, String] = Map([])
  let mut definition_fence : (Char, Int)? = None
  let mut definition_comment = false
  for raw in lines {
    let (visible, in_comment) = if definition_fence is None {
      document_visible_line(raw.to_owned(), definition_comment)
    } else {
      (raw.to_owned(), definition_comment)
    }
    definition_comment = in_comment
    let line = visible.trim()
    if definition_fence is Some((ch, size)) {
      if document_fence(line) is Some((closing, count, info)) &&
        closing == ch &&
        count >= size &&
        info == "" {
        definition_fence = None
      }
      continue
    }
    if document_fence(line) is Some((ch, size, _)) {
      definition_fence = Some((ch, size))
      continue
    }
    if document_definition(line) is Some((id, source)) {
      definitions.set(id, source)
    }
  }
  let mut unbound_snippets = 0
  let mut fence_char : Char? = None
  let mut fence_size = 0
  let mut fence_line = 0
  let mut snippet_source : String? = None
  let snippet_lines : Array[String] = []
  let mut pending_quote : (Int, String)? = None
  let mut in_comment = false
  for index = 0; index < lines.length(); index = index + 1 {
    let (visible, next_comment) = if fence_char is None {
      document_visible_line(lines[index].to_owned(), in_comment)
    } else {
      (lines[index].to_owned(), in_comment)
    }
    in_comment = next_comment
    let line = visible.trim()
    let number = index + 1
    let fence = document_fence(line)
    if fence_char is Some(open_char) {
      if fence is Some((close_char, size, info)) &&
        close_char == open_char &&
        size >= fence_size &&
        info.trim() == "" {
        match snippet_source {
          Some(source) => {
            let excerpt = snippet_lines.join("\n")
            if excerpt.trim() == "" {
              add_diagnostic(
                diagnostics, fence_line, "EMPTY_SNIPPET", "source-bound snippet is empty",
              )
            } else {
              references.push({
                line: fence_line,
                source,
                kind: "snippet",
                excerpt: Some(excerpt),
              })
            }
          }
          None => unbound_snippets = unbound_snippets + 1
        }
        fence_char = None
        snippet_source = None
        snippet_lines.clear()
      } else {
        snippet_lines.push(lines[index].to_owned())
      }
      continue
    }
    if fence is Some((ch, size, info)) {
      fence_char = Some(ch)
      fence_size = size
      fence_line = number
      snippet_source = snippet_source_attribute(info)
      if info.contains("source=") && snippet_source is None {
        add_diagnostic(
          diagnostics, number, "INVALID_SNIPPET_SOURCE", "source= needs a nonempty path or URL",
        )
      }
      continue
    }
    if line.has_prefix("[//]:") {
      continue
    }
    if document_definition(line) is Some(_) {
      continue
    }
    if report_quote_line(line) is Some(quote) {
      if pending_quote is Some((previous, _)) {
        add_diagnostic(
          diagnostics, previous, "MISSING_REPORT_SOURCE", "quote has no following source",
        )
      }
      pending_quote = Some((number, quote))
      continue
    }
    let content = line.strip_prefix(">").unwrap_or(line).trim()
    let source_line = match content.strip_prefix("来源：") {
      Some(value) => Some(value)
      None => content.strip_prefix("Source:")
    }
    if source_line is Some(raw_source) {
      let links = document_links(raw_source, definitions)
      let source = if links.length() == 1 {
        links[0].source
      } else {
        raw_source.trim().to_owned()
      }
      match pending_quote {
        Some((quote_line, quote)) =>
          if source == "" || quote == "" {
            add_diagnostic(
              diagnostics, number, "INVALID_REPORT_SOURCE", "quote and source must be nonempty",
            )
          } else {
            references.push({
              line: quote_line,
              source,
              kind: "quote",
              excerpt: Some(quote),
            })
          }
        None =>
          add_diagnostic(
            diagnostics, number, "SOURCE_WITHOUT_QUOTE", "source has no preceding quote",
          )
      }
      pending_quote = None
      continue
    }
    if pending_quote is Some((quote_line, _)) && line != "" && line != ">" {
      add_diagnostic(
        diagnostics, quote_line, "MISSING_REPORT_SOURCE", "quote has no following source",
      )
      pending_quote = None
    }
    let links = document_links(line, definitions)
    let html_tags = document_html_tags(line)
    for tag in html_tags {
      if tag.source != "" {
        links.push(tag)
      }
    }
    let used : Map[Int, Bool] = Map([])
    let chars = line.to_owned().to_array()
    let mut position = 0
    while position < chars.length() {
      let ch = chars[position]
      if ch == '`' {
        position = document_code_span_end(chars, position)
        continue
      }
      if (ch != '“' && ch != '"') ||
        document_is_escaped(chars, position) ||
        links.any(link => position >= link.start && position < link.end) ||
        html_tags.any(tag => position >= tag.start && position < tag.end) {
        position = position + 1
        continue
      }
      let close = if ch == '“' { '”' } else { '"' }
      let mut end = position + 1
      while end < chars.length() {
        if chars[end] == '`' {
          end = document_code_span_end(chars, end)
          continue
        }
        if chars[end] == close && !document_is_escaped(chars, end) {
          break
        }
        end = end + 1
      }
      if end == chars.length() {
        add_diagnostic(
          warnings, number, "UNCLOSED_QUOTE", "quotation is not closed on the same line",
        )
        break
      }
      let mut associated : Int? = None
      for link_index = 0
          link_index < links.length()
          link_index = link_index + 1 {
        let link = links[link_index]
        if link.start > end && link.start - end <= 85 {
          let between = String::from_array(chars[end + 1:link.start])
          if !between.contains("“") &&
            !between.contains("\"") &&
            !between.contains(";") &&
            !between.contains("；") &&
            !between.contains("。") &&
            !between.contains(".") {
            associated = Some(link_index)
            break
          }
        }
      }
      if associated is None &&
        (line.has_prefix("- [") || line.has_prefix("* [")) &&
        links.length() > 0 &&
        links[0].end <= position {
        let between = String::from_array(chars[links[0].end:position]).trim()
        if between.has_prefix("-") || between.has_prefix("—") {
          associated = Some(0)
        }
      }
      let quote = clean_report_quote(
        String::from_array(chars[position + 1:end])[:],
      )
      match associated {
        Some(link_index) => {
          if links[link_index].source == "" {
            add_diagnostic(
              warnings, number, "UNRESOLVED_REFERENCE_LINK", "source link has no destination or matching definition",
            )
          } else if quote == "" {
            add_diagnostic(
              diagnostics, number, "EMPTY_REPORT_QUOTE", "quote is empty",
            )
          } else {
            references.push({
              line: number,
              source: links[link_index].source,
              kind: "quote",
              excerpt: Some(quote),
            })
          }
          used.set(link_index, true)
        }
        None =>
          add_diagnostic(
            warnings, number, "UNASSOCIATED_QUOTE", "quotation has no supported same-line source link; add a quote/source block",
          )
      }
      position = end + 1
    }
    for link_index = 0; link_index < links.length(); link_index = link_index + 1 {
      if used.get(link_index) is None {
        if links[link_index].source == "" {
          add_diagnostic(
            warnings, number, "UNRESOLVED_REFERENCE_LINK", "link has no destination or matching definition",
          )
        } else {
          references.push({
            line: number,
            source: links[link_index].source,
            kind: "link",
            excerpt: None,
          })
        }
      }
    }
  }
  if fence_char is Some(_) {
    add_diagnostic(
      diagnostics, fence_line, "UNCLOSED_CODE_FENCE", "code fence is not closed",
    )
  }
  if pending_quote is Some((number, _)) {
    add_diagnostic(
      diagnostics, number, "MISSING_REPORT_SOURCE", "quote has no following source",
    )
  }
  { references, diagnostics, warnings, unbound_snippets, }
}

///|
fn document_fence(line : StringView) -> (Char, Int, String)? {
  let chars = line.to_owned().to_array()
  if chars.length() < 3 || (chars[0] != '`' && chars[0] != '~') {
    return None
  }
  let mut count = 0
  while count < chars.length() && chars[count] == chars[0] {
    count = count + 1
  }
  if count < 3 {
    return None
  }
  Some((chars[0], count, String::from_array(chars[count:]).trim().to_owned()))
}

///|
fn snippet_source_attribute(info : String) -> String? {
  let (_, tail) = match info.split_once("source=") {
    Some(parts) => parts
    None => return None
  }
  let tail = tail.trim()
  let value = if tail.has_prefix("\"") {
    match tail[1:].split_once("\"") {
      Some((value, _)) => value.to_owned()
      None => return None
    }
  } else {
    tail.split(" ").next().unwrap_or("").to_owned()
  }
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
/// Balanced destinations support parentheses in local filenames and URLs.
fn document_links(
  line : StringView,
  definitions : Map[String, String],
  nesting? : Int = 0,
) -> Array[MarkdownLink] {
  let chars = line.to_owned().to_array()
  let html_tags = document_html_tags(line)
  let mut tag_index = 0
  let links : Array[MarkdownLink] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '`' {
      index = document_code_span_end(chars, index)
      continue
    }
    // Skip attributes only when scanning an actual HTML tag. A Markdown link
    // already consumes its destination, including <paths with spaces>.
    while tag_index < html_tags.length() && html_tags[tag_index].end <= index {
      tag_index = tag_index + 1
    }
    if tag_index < html_tags.length() && html_tags[tag_index].start == index {
      index = html_tags[tag_index].end
      continue
    }
    if chars[index] != '[' || document_is_escaped(chars, index) {
      index = index + 1
      continue
    }
    let start = index
    let mut close = index + 1
    let mut bracket_depth = 1
    while close < chars.length() && bracket_depth > 0 {
      if !document_is_escaped(chars, close) {
        if chars[close] == '[' {
          bracket_depth = bracket_depth + 1
        }
        if chars[close] == ']' {
          bracket_depth = bracket_depth - 1
        }
      }
      if bracket_depth == 0 {
        break
      }
      close = close + 1
    }
    if close >= chars.length() {
      index = index + 1
      continue
    }
    let label_text = String::from_array(chars[start + 1:close])
    if nesting < 8 && label_text.contains("](") {
      for
        child in document_links(label_text[:], definitions, nesting=nesting + 1) {
        links.push({
          start: start + 1 + child.start,
          end: start + 1 + child.end,
          source: child.source,
        })
      }
    }
    let label = normalize_web_text(label_text).to_lower()
    if close + 1 < chars.length() && chars[close + 1] == '[' {
      let mut end = close + 2
      while end < chars.length() && chars[end] != ']' {
        end = end + 1
      }
      if end == chars.length() {
        index = index + 1
        continue
      }
      let id = String::from_array(chars[close + 2:end])
      let id = if id == "" { label } else { normalize_web_text(id).to_lower() }
      links.push({
        start,
        end: end + 1,
        source: definitions.get(id).unwrap_or(""),
      })
      index = end + 1
      continue
    }
    if close + 1 >= chars.length() || chars[close + 1] != '(' {
      if definitions.get(label) is Some(source) {
        links.push({ start, end: close + 1, source, })
        index = close + 1
        continue
      }
      index = index + 1
      continue
    }
    let mut end = close + 2
    let mut depth = 1
    while end < chars.length() && depth > 0 {
      if !document_is_escaped(chars, end) {
        if chars[end] == '(' {
          depth = depth + 1
        }
        if chars[end] == ')' {
          depth = depth - 1
        }
      }
      if depth > 0 {
        end = end + 1
      }
    }
    if depth != 0 {
      links.push({ start, end: chars.length(), source: "", })
      index = chars.length()
      continue
    }
    let raw = String::from_array(chars[close + 2:end]).trim()
    let destination = if raw.has_prefix("<") {
      match raw[1:].split_once(">") {
        Some((value, _)) => value.to_owned()
        None => raw.to_owned()
      }
    } else {
      raw.split(" ").next().unwrap_or("").to_owned()
    }
    links.push({ start, end: end + 1, source: destination, })
    index = end + 1
  }
  links
}

///|
fn document_is_escaped(chars : Array[Char], index : Int) -> Bool {
  let mut before = index
  while before > 0 && chars[before - 1] == '\\' {
    before = before - 1
  }
  (index - before) % 2 == 1
}

///|
/// Code spans close only at a backtick run of the same length. An unmatched
/// opener is literal text, so advance only past that run instead of hiding the
/// rest of the line. Backslashes inside a code span do not escape its closer.
fn document_code_span_end(chars : Array[Char], start : Int) -> Int {
  if document_is_escaped(chars, start) {
    return start + 1
  }
  let mut opening_end = start + 1
  while opening_end < chars.length() && chars[opening_end] == '`' {
    opening_end = opening_end + 1
  }
  let mut index = opening_end
  while index < chars.length() {
    if chars[index] != '`' {
      index = index + 1
      continue
    }
    let closing_start = index
    while index < chars.length() && chars[index] == '`' {
      index = index + 1
    }
    if index - closing_start == opening_end - start {
      return index
    }
  }
  opening_end
}

///|
/// Mask comments outside code fences, retaining the character positions of
/// subsequent visible links on the same line.
fn document_visible_line(raw : String, active : Bool) -> (String, Bool) {
  let chars = raw.to_array()
  let output = StringBuilder()
  let mut in_comment = active
  let mut index = 0
  while index < chars.length() {
    if !in_comment && chars[index] == '`' {
      let end = document_code_span_end(chars, index)
      output.write_string(String::from_array(chars[index:end]))
      index = end
      continue
    }
    if !in_comment &&
      index + 3 < chars.length() &&
      chars[index] == '<' &&
      chars[index + 1] == '!' &&
      chars[index + 2] == '-' &&
      chars[index + 3] == '-' {
      in_comment = true
      output.write_string("    ")
      index = index + 4
      continue
    }
    if in_comment &&
      index + 2 < chars.length() &&
      chars[index] == '-' &&
      chars[index + 1] == '-' &&
      chars[index + 2] == '>' {
      in_comment = false
      output.write_string("   ")
      index = index + 3
      continue
    }
    output.write_char(if in_comment { ' ' } else { chars[index] })
    index = index + 1
  }
  (output.to_string(), in_comment)
}

///|
fn document_definition(line : StringView) -> (String, String)? {
  if !line.has_prefix("[") {
    return None
  }
  let (label, tail) = match line[1:].split_once("]:") {
    Some(parts) => parts
    None => return None
  }
  let tail = tail.trim()
  let source = if tail.has_prefix("<") {
    match tail[1:].split_once(">") {
      Some((value, _)) => value.to_owned()
      None => return None
    }
  } else {
    tail.split(" ").next().unwrap_or("").to_owned()
  }
  if source == "" {
    return None
  }
  Some((normalize_web_text(label.to_owned()).to_lower(), source))
}

///|
/// HTML presentation attributes are not prose citations. href/src attributes
/// contribute ordinary dependencies, such as a README's SVG hero.
fn document_html_tags(line : StringView) -> Array[MarkdownLink] {
  let chars = line.to_owned().to_array()
  let tags : Array[MarkdownLink] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '`' {
      index = document_code_span_end(chars, index)
      continue
    }
    if chars[index] != '<' || index + 1 >= chars.length() {
      index = index + 1
      continue
    }
    let next = chars[index + 1]
    if !((next >= 'a' && next <= 'z') ||
      (next >= 'A' && next <= 'Z') ||
      next == '/') {
      index = index + 1
      continue
    }
    let start = index
    let mut end = index + 1
    let mut quote : Char? = None
    while end < chars.length() {
      let ch = chars[end]
      match quote {
        Some(mark) => if ch == mark { quote = None }
        None =>
          if ch == '"' || ch == '\'' {
            quote = Some(ch)
          } else if ch == '>' {
            break
          }
      }
      end = end + 1
    }
    if end == chars.length() {
      index = index + 1
      continue
    }
    tags.push({ start, end: end + 1, source: "", })
    let mut attribute = start + 1
    while attribute < end {
      if chars[attribute] != ' ' && chars[attribute] != '\t' {
        attribute = attribute + 1
        continue
      }
      while attribute < end &&
            (chars[attribute] == ' ' || chars[attribute] == '\t') {
        attribute = attribute + 1
      }
      let name_start = attribute
      while attribute < end &&
            chars[attribute] != '=' &&
            chars[attribute] != ' ' &&
            chars[attribute] != '\t' {
        attribute = attribute + 1
      }
      let name = String::from_array(chars[name_start:attribute]).to_lower()
      while attribute < end &&
            (chars[attribute] == ' ' || chars[attribute] == '\t') {
        attribute = attribute + 1
      }
      if attribute >= end || chars[attribute] != '=' {
        continue
      }
      attribute = attribute + 1
      while attribute < end &&
            (chars[attribute] == ' ' || chars[attribute] == '\t') {
        attribute = attribute + 1
      }
      if attribute >= end {
        break
      }
      let mark = if chars[attribute] == '"' || chars[attribute] == '\'' {
        Some(chars[attribute])
      } else {
        None
      }
      if mark is Some(_) {
        attribute = attribute + 1
      }
      let value_start = attribute
      while attribute < end {
        if mark is Some(ch) {
          if chars[attribute] == ch {
            break
          }
        } else if chars[attribute] == ' ' || chars[attribute] == '\t' {
          break
        }
        attribute = attribute + 1
      }
      if name == "src" || name == "href" {
        let source = String::from_array(chars[value_start:attribute]).replace_all(
          old="&amp;",
          new="&",
        )
        if source != "" {
          tags.push({ start, end: end + 1, source, })
        }
      }
      if mark is Some(_) {
        attribute = attribute + 1
      }
    }
    index = end + 1
  }
  tags
}
