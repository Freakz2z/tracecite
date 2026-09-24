///|
fn field(value : Json, key : String) -> Json? {
  if value is Object(object) {
    object.get(key)
  } else {
    None
  }
}

///|
fn required_string(
  value : Json,
  key : String,
  line : Int,
  diagnostics : Array[Diagnostic],
) -> String? {
  match field(value, key) {
    Some(String(text)) if text != "" => Some(text)
    _ => {
      add_diagnostic(
        diagnostics,
        line,
        "INVALID_FIELD",
        "expected nonempty string: " + key,
      )
      None
    }
  }
}

///|
fn required_bool(
  value : Json,
  key : String,
  line : Int,
  diagnostics : Array[Diagnostic],
) -> Bool? {
  match field(value, key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => {
      add_diagnostic(
        diagnostics,
        line,
        "INVALID_FIELD",
        "expected boolean: " + key,
      )
      None
    }
  }
}

///|
fn optional_string(
  value : Json,
  key : String,
  line : Int,
  diagnostics : Array[Diagnostic],
) -> String? {
  match field(value, key) {
    None => None
    Some(String(text)) if text != "" => Some(text)
    _ => {
      add_diagnostic(
        diagnostics,
        line,
        "INVALID_FIELD",
        "expected nonempty string: " + key,
      )
      None
    }
  }
}

///|
fn parse_sources(
  value : Json,
  line : Int,
  diagnostics : Array[Diagnostic],
) -> Array[Source]? {
  match field(value, "sources") {
    None => Some([])
    Some(Array(items)) => {
      let sources : Array[Source] = []
      let before = diagnostics.length()
      for item in items {
        if item is Object(_) {
          let id = required_string(item, "id", line, diagnostics)
          let uri = required_string(item, "uri", line, diagnostics)
          let title = optional_string(item, "title", line, diagnostics)
          let content = optional_string(item, "content", line, diagnostics)
          match (id, uri) {
            (Some(id), Some(uri)) => sources.push({ id, uri, title, content, })
            _ => ()
          }
        } else {
          add_diagnostic(
            diagnostics, line, "INVALID_FIELD", "expected object in sources",
          )
        }
      }
      if diagnostics.length() == before {
        Some(sources)
      } else {
        None
      }
    }
    _ => {
      add_diagnostic(
        diagnostics, line, "INVALID_FIELD", "expected array: sources",
      )
      None
    }
  }
}

///|
fn parse_citations(
  value : Json,
  line : Int,
  diagnostics : Array[Diagnostic],
) -> Array[ClaimCitation]? {
  if field(value, "citations") is Some(Array(items)) {
    if field(value, "source_ids") is Some(_) {
      add_diagnostic(
        diagnostics, line, "INVALID_FIELD", "use citations or source_ids, not both",
      )
      return None
    }
    let citations : Array[ClaimCitation] = []
    let before = diagnostics.length()
    for item in items {
      let source_id = required_string(item, "source_id", line, diagnostics)
      let quote = required_string(item, "quote", line, diagnostics)
      match (source_id, quote) {
        (Some(source_id), Some(quote)) =>
          citations.push({ source_id, quote: Some(quote), })
        _ => ()
      }
    }
    return if diagnostics.length() == before { Some(citations) } else { None }
  }
  match field(value, "source_ids") {
    Some(Array(items)) => {
      let ids : Array[ClaimCitation] = []
      let before = diagnostics.length()
      for item in items {
        match item {
          String(id) if id != "" => ids.push({ source_id: id, quote: None, })
          _ =>
            add_diagnostic(
              diagnostics, line, "INVALID_FIELD", "expected nonempty string in source_ids",
            )
        }
      }
      if diagnostics.length() == before {
        Some(ids)
      } else {
        None
      }
    }
    _ => {
      add_diagnostic(
        diagnostics, line, "INVALID_FIELD", "expected array: source_ids",
      )
      None
    }
  }
}

///|
fn parse_claims(
  value : Json,
  line : Int,
  diagnostics : Array[Diagnostic],
) -> Array[Claim]? {
  match field(value, "claims") {
    Some(Array(items)) => {
      let claims : Array[Claim] = []
      let before = diagnostics.length()
      for item in items {
        if item is Object(_) {
          let text = required_string(item, "text", line, diagnostics)
          let citations = parse_citations(item, line, diagnostics)
          match (text, citations) {
            (Some(_), Some(citations)) => claims.push({ citations, })
            _ => ()
          }
        } else {
          add_diagnostic(
            diagnostics, line, "INVALID_FIELD", "expected object in claims",
          )
        }
      }
      if diagnostics.length() == before {
        Some(claims)
      } else {
        None
      }
    }
    _ => {
      add_diagnostic(
        diagnostics, line, "INVALID_FIELD", "expected array: claims",
      )
      None
    }
  }
}

///|
fn parse_event(
  value : Json,
  line : Int,
  diagnostics : Array[Diagnostic],
) -> Event? {
  match value {
    Object(_) => ()
    _ => {
      add_diagnostic(diagnostics, line, "INVALID_EVENT", "expected JSON object")
      return None
    }
  }
  let event_type = required_string(value, "type", line, diagnostics)
  let run_id = required_string(value, "run_id", line, diagnostics)
  match (event_type, run_id) {
    (Some("tool_call"), Some(run_id)) => {
      let call_id = required_string(value, "call_id", line, diagnostics)
      let tool = required_string(value, "tool", line, diagnostics)
      match (call_id, tool) {
        (Some(call_id), Some(_)) => Some(ToolCall(run_id, call_id, line))
        _ => None
      }
    }
    (Some("tool_result"), Some(run_id)) => {
      let call_id = required_string(value, "call_id", line, diagnostics)
      let ok = required_bool(value, "ok", line, diagnostics)
      let sources = parse_sources(value, line, diagnostics)
      match (call_id, ok, sources) {
        (Some(call_id), Some(ok), Some(sources)) =>
          Some(ToolResult(run_id, call_id, ok, sources, line))
        _ => None
      }
    }
    (Some("answer"), Some(run_id)) => {
      let claims = parse_claims(value, line, diagnostics)
      match claims {
        Some(claims) => Some(Answer(run_id, claims, line))
        None => None
      }
    }
    (Some(kind), Some(_)) => {
      add_diagnostic(
        diagnostics,
        line,
        "UNKNOWN_EVENT",
        "unknown event type: " + kind,
      )
      None
    }
    _ => None
  }
}

///|
fn parse_json_line(text : StringView) -> Json? {
  Some(@json.parse(text)) catch {
    _ => None
  }
}

///|
fn parse_jsonl(input : String, diagnostics : Array[Diagnostic]) -> Array[Event] {
  let events : Array[Event] = []
  let lines = input.split("\n").to_array()
  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i].trim()
    if line != "" {
      match parse_json_line(line) {
        Some(value) =>
          match parse_event(value, i + 1, diagnostics) {
            Some(event) => events.push(event)
            None => ()
          }
        None =>
          add_diagnostic(diagnostics, i + 1, "INVALID_JSON", "invalid JSON")
      }
    }
  }
  events
}
