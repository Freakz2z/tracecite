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
    collect_inline_report_quotes(line, heading, line_number, notes, diagnostics)
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
/// Find ordinary Markdown citations such as “quoted text” ([source](https://...)).
/// A nearby link without an explicit quotation is deliberately not treated as
/// proof for the surrounding claim.
fn collect_inline_report_quotes(
  line : StringView,
  heading : String,
  line_number : Int,
  notes : Array[CitationNote],
  diagnostics : Array[Diagnostic],
) -> Unit {
  let mut remaining = line
  while true {
    let (before_open, after_open) = match remaining.split_once("“") {
      Some(parts) => parts
      None => break
    }
    let (quote, after_close) = match after_open.split_once("”") {
      Some(parts) => parts
      None => break
    }
    remaining = after_close
    let source = match inline_report_source(after_close) {
      Some(url) => Some(url)
      None => source_before_inline_quote(before_open)
    }
    match source {
      Some(url) =>
        if url == "" {
          add_diagnostic(
            diagnostics, line_number, "INVALID_REPORT_SOURCE", "source needs an HTTP URL",
          )
        } else {
          let cleaned = clean_report_quote(quote)
          if cleaned == "" {
            add_diagnostic(
              diagnostics, line_number, "EMPTY_REPORT_QUOTE", "quote is empty",
            )
          } else {
            notes.push({
              claim: heading,
              quote: cleaned,
              url,
              line: line_number,
            })
          }
        }
      None => ()
    }
  }
}

///|
/// In curated Markdown lists, the linked title often precedes its quotation.
/// Restrict this form to a list item whose first element is a linked title.
fn source_before_inline_quote(before_quote : StringView) -> String? {
  let before = before_quote.trim()
  let title = match before.strip_prefix("- [") {
    Some(rest) => rest
    None =>
      match before.strip_prefix("* [") {
        Some(rest) => rest
        None => return None
      }
  }
  let (_, url_tail) = match title.split_once("](") {
    Some(parts) => parts
    None => return Some("")
  }
  let (url, after_link) = match url_tail.split_once(")") {
    Some(parts) => parts
    None => return Some("")
  }
  let after_link = after_link.trim()
  if !after_link.has_prefix("-") && !after_link.has_prefix("—") {
    return None
  }
  let url = url.trim()
  if url.has_prefix("https://") || url.has_prefix("http://") {
    Some(url.to_owned())
  } else {
    Some("")
  }
}

///|
fn inline_report_source(after_quote : StringView) -> String? {
  let tail = after_quote.trim()
  let tail = match tail.strip_prefix("（") {
    Some(rest) => rest
    None =>
      match tail.strip_prefix("(") {
        Some(rest) => rest
        None =>
          match tail.split_once("（") {
            Some((between, rest)) if between.length() <= 80 &&
              !between.contains("。") &&
              !between.contains("；") &&
              !between.contains("“") &&
              rest.has_prefix("[") => rest
            _ =>
              match tail.split_once("(") {
                Some((between, rest)) if between.length() <= 80 &&
                  !between.contains(".") &&
                  !between.contains(";") &&
                  !between.contains("\"") &&
                  rest.has_prefix("[") => rest
                _ =>
                  if tail.has_prefix("[") {
                    tail
                  } else {
                    match tail.split_once("[") {
                      Some((between, rest)) if between.length() <= 80 &&
                        between.trim().has_prefix("-") => rest
                      _ => return None
                    }
                  }
              }
          }
      }
  }
  let (_, url_tail) = match tail.split_once("](") {
    Some(parts) => parts
    None => return Some("")
  }
  let (url, _) = match url_tail.split_once(")") {
    Some(parts) => parts
    None => return Some("")
  }
  let url = url.trim()
  if url.has_prefix("https://") || url.has_prefix("http://") {
    Some(url.to_owned())
  } else {
    Some("")
  }
}

///|
fn clean_report_quote(raw : StringView) -> String {
  let output = StringBuilder()
  for char in raw.iter() {
    if char != '`' {
      output.write_char(char)
    }
  }
  output.to_string().trim().to_owned()
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
  clean_report_quote(unquoted) |> Some
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
