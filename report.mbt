///|
/// Parse Markdown citation blocks of the form:
/// > 原文：“quoted text”
/// > 来源：[title](https://example.org/page)
/// Inline-code backticks are Markdown formatting, not part of rendered quotes.
pub fn parse_markdown_report(input : String) -> CitationNotes {
  let notes : Array[CitationNote] = []
  let diagnostics : Array[Diagnostic] = []
  let mut heading = "Markdown report"
  let mut pending_quote : String? = None
  let mut pending_line = 0
  let mut in_code_block = false
  let lines = input.split("\n").to_array()
  for index = 0; index < lines.length(); index = index + 1 {
    let line_number = index + 1
    let line = lines[index].trim()
    if line.has_prefix("```") || line.has_prefix("~~~") {
      in_code_block = !in_code_block
      continue
    }
    if in_code_block {
      continue
    }
    if line.has_prefix("#") {
      if pending_quote is Some(_) {
        add_diagnostic(
          diagnostics, pending_line, "MISSING_REPORT_SOURCE", "quote has no following source",
        )
        pending_quote = None
      }
      heading = match line.split_once(" ") {
        Some((_, title)) => title.trim().to_owned()
        None => line.to_owned()
      }
      continue
    }
    match report_quote_line(line) {
      Some(quote) => {
        if pending_quote is Some(_) {
          add_diagnostic(
            diagnostics, pending_line, "MISSING_REPORT_SOURCE", "quote has no following source",
          )
        }
        if quote == "" {
          add_diagnostic(
            diagnostics, line_number, "EMPTY_REPORT_QUOTE", "quote is empty",
          )
          pending_quote = None
        } else {
          pending_quote = Some(quote)
          pending_line = line_number
        }
        continue
      }
      None => ()
    }
    match report_source_line(line) {
      Some(url) => {
        match pending_quote {
          Some(quote) =>
            if url == "" {
              add_diagnostic(
                diagnostics, line_number, "INVALID_REPORT_SOURCE", "source needs an HTTP URL",
              )
            } else {
              notes.push({ claim: heading, quote, url, line: pending_line, })
            }
          None =>
            add_diagnostic(
              diagnostics, line_number, "SOURCE_WITHOUT_QUOTE", "source has no preceding quote",
            )
        }
        pending_quote = None
        continue
      }
      None => ()
    }
    if pending_quote is Some(_) && line != "" && line != ">" {
      add_diagnostic(
        diagnostics, pending_line, "MISSING_REPORT_SOURCE", "quote has no following source",
      )
      pending_quote = None
    }
  }
  if pending_quote is Some(_) {
    add_diagnostic(
      diagnostics, pending_line, "MISSING_REPORT_SOURCE", "quote has no following source",
    )
  }
  if notes.is_empty() && diagnostics.is_empty() {
    add_diagnostic(
      diagnostics, 1, "NO_REPORT_CITATIONS", "no quote/source blocks found",
    )
  }
  { notes, diagnostics, }
}

///|
fn report_quote_line(line : StringView) -> String? {
  let content = match line.strip_prefix(">") {
    Some(rest) => rest.trim()
    None => return None
  }
  let raw = match content.strip_prefix("原文：") {
    Some(rest) => rest
    None =>
      match content.strip_prefix("引文：") {
        Some(rest) => rest
        None =>
          match content.strip_prefix("Quote:") {
            Some(rest) => rest
            None => return None
          }
      }
  }
  let raw = raw.trim()
  let unquoted = match raw.strip_prefix("“") {
    Some(rest) => rest.strip_suffix("”").unwrap_or(rest)
    None =>
      match raw.strip_prefix("\"") {
        Some(rest) => rest.strip_suffix("\"").unwrap_or(rest)
        None => raw
      }
  }
  let output = StringBuilder()
  for char in unquoted.iter() {
    if char != '`' {
      output.write_char(char)
    }
  }
  output.to_string().trim().to_owned() |> Some
}

///|
fn report_source_line(line : StringView) -> String? {
  let content = match line.strip_prefix(">") {
    Some(rest) => rest.trim()
    None => return None
  }
  let raw = match content.strip_prefix("来源：") {
    Some(rest) => rest.trim()
    None =>
      match content.strip_prefix("Source:") {
        Some(rest) => rest.trim()
        None => return None
      }
  }
  let url = if raw.has_prefix("[") {
    match raw.split_once("](") {
      Some((_, tail)) =>
        match tail.split_once(")") {
          Some((url, _)) => url.trim().to_owned()
          None => ""
        }
      None => ""
    }
  } else {
    raw.to_owned()
  }
  if url.has_prefix("https://") || url.has_prefix("http://") {
    Some(url)
  } else {
    Some("")
  }
}
