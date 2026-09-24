///|
/// Check that a source snapshot in a valid trace exactly matches independently
/// supplied content. The caller controls how the content is obtained.
pub fn source_snapshot_matches(
  input : String,
  uri : String,
  live_content : String,
) -> Bool {
  let diagnostics : Array[Diagnostic] = []
  let events = parse_jsonl(input, diagnostics)
  if !diagnostics.is_empty() {
    return false
  }
  for event in events {
    if event is ToolResult(_, _, true, sources, _) {
      for source in sources {
        if source.uri == uri && source.content is Some(content) {
          return content == live_content
        }
      }
    }
  }
  false
}
