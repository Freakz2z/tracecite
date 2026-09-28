///|
/// One citation note from the lightweight claim/quote/url input format.
pub(all) struct CitationNote {
  claim : String
  quote : String
  url : String
  line : Int
} derive(ToJson)

///|
pub extend CitationNote with ToJson::{to_json}

///|
/// Parsed citation notes and line-based input diagnostics.
pub(all) struct CitationNotes {
  notes : Array[CitationNote]
  diagnostics : Array[Diagnostic]
} derive(ToJson)

///|
pub extend CitationNotes with ToJson::{to_json}

///|
/// Parse the lightweight plain-text format. Each record has one `claim:`,
/// `quote:`, and `url:` line; blank lines or `---` separate records.
/// Field values are single-line strings.
pub fn parse_citation_notes(input : String) -> CitationNotes {
  let notes : Array[CitationNote] = []
  let diagnostics : Array[Diagnostic] = []
  let mut claim : String? = None
  let mut quote : String? = None
  let mut url : String? = None
  let mut record_line = 1
  let mut record_invalid = false

  let lines = input.split("\n").to_array()
  for index = 0; index < lines.length(); index = index + 1 {
    let line_number = index + 1
    let raw_line = lines[index]
    let line = raw_line.trim()
    if line == "" || line == "---" {
      finish_citation_note(
        notes, diagnostics, record_line, claim, quote, url, record_invalid,
      )
      claim = None
      quote = None
      url = None
      record_line = line_number + 1
      record_invalid = false
      continue
    }
    if line.has_prefix("#") {
      continue
    }
    if claim is None && quote is None && url is None && !record_invalid {
      record_line = line_number
    }
    match line.split_once(":") {
      None => {
        add_diagnostic(
          diagnostics, line_number, "INVALID_NOTE_LINE", "expected claim:, quote:, or url:",
        )
        record_invalid = true
      }
      Some((key_view, value_view)) => {
        let key = key_view.trim().to_owned()
        let value = value_view.trim().to_owned()
        if value == "" {
          add_diagnostic(
            diagnostics,
            line_number,
            "EMPTY_NOTE_FIELD",
            "field value cannot be empty: " + key,
          )
          record_invalid = true
          continue
        }
        match key {
          "claim" =>
            if claim is Some(_) {
              add_diagnostic(
                diagnostics, line_number, "DUPLICATE_NOTE_FIELD", "duplicate claim field",
              )
              record_invalid = true
            } else {
              claim = Some(value)
            }
          "quote" =>
            if quote is Some(_) {
              add_diagnostic(
                diagnostics, line_number, "DUPLICATE_NOTE_FIELD", "duplicate quote field",
              )
              record_invalid = true
            } else {
              quote = Some(value)
            }
          "url" =>
            if url is Some(_) {
              add_diagnostic(
                diagnostics, line_number, "DUPLICATE_NOTE_FIELD", "duplicate url field",
              )
              record_invalid = true
            } else {
              url = Some(value)
            }
          _ => {
            add_diagnostic(
              diagnostics,
              line_number,
              "UNKNOWN_NOTE_FIELD",
              "unknown note field: " + key,
            )
            record_invalid = true
          }
        }
      }
    }
  }
  finish_citation_note(
    notes, diagnostics, record_line, claim, quote, url, record_invalid,
  )
  if notes.is_empty() && diagnostics.is_empty() {
    add_diagnostic(
      diagnostics, 1, "EMPTY_NOTE_INPUT", "no citation notes found",
    )
  }
  { notes, diagnostics, }
}

///|
fn finish_citation_note(
  notes : Array[CitationNote],
  diagnostics : Array[Diagnostic],
  line : Int,
  claim : String?,
  quote : String?,
  url : String?,
  invalid : Bool,
) -> Unit {
  if claim is None && quote is None && url is None && !invalid {
    return
  }
  if claim is None {
    add_diagnostic(
      diagnostics, line, "MISSING_NOTE_FIELD", "missing claim field",
    )
  }
  if quote is None {
    add_diagnostic(
      diagnostics, line, "MISSING_NOTE_FIELD", "missing quote field",
    )
  }
  if url is None {
    add_diagnostic(diagnostics, line, "MISSING_NOTE_FIELD", "missing url field")
  }
  if !invalid {
    match (claim, quote, url) {
      (Some(claim), Some(quote), Some(url)) =>
        notes.push({ claim, quote, url, line, })
      _ => ()
    }
  }
}
