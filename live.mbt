///|
/// Result for one quote checked against the current text fetched from a source.
pub(all) struct LiveCitationMatch {
  source_id : String
  claim_index : Int
  quote_present : Bool
} derive(ToJson)

///|
pub extend LiveCitationMatch with ToJson::{to_json}

///|
/// Check citations to `uri` against its current fetched text. Whitespace is
/// collapsed to account for HTML layout while preserving case and punctuation.
pub fn check_live_source_quotes(
  input : String,
  uri : String,
  live_content : String,
) -> Array[LiveCitationMatch] {
  let source_ids : Map[String, Bool] = Map([])
  let events = parse_jsonl(input, [])
  for event in events {
    if event is ToolResult(_, _, true, sources, _) {
      for source in sources {
        if source.uri == uri {
          source_ids.set(source.id, true)
        }
      }
    }
  }
  let normalized_live = normalize_web_text(live_content)
  let matches : Array[LiveCitationMatch] = []
  for event in events {
    if event is Answer(_, claims, _) {
      for claim_index = 0
          claim_index < claims.length()
          claim_index = claim_index + 1 {
        for citation in claims[claim_index].citations {
          if source_ids.get(citation.source_id) is Some(_) {
            let quote_present = match citation.quote {
              Some(quote) => {
                let normalized_quote = normalize_web_text(quote)
                normalized_quote != "" &&
                normalized_live.contains(normalized_quote)
              }
              None => false
            }
            matches.push({
              source_id: citation.source_id,
              claim_index: claim_index + 1,
              quote_present,
            })
          }
        }
      }
    }
  }
  matches
}

///|
/// Collapse Unicode whitespace, including spaces before punctuation that HTML
/// text extraction can introduce around inline elements.
pub fn normalize_web_text(input : String) -> String {
  let out = StringBuilder()
  let mut has_text = false
  let mut pending_space = false
  let mut after_open_delimiter = false
  for ch in input.iter() {
    if ch.is_whitespace() {
      if has_text {
        pending_space = true
      }
    } else {
      if pending_space {
        if !after_open_delimiter &&
          ch != ')' &&
          ch != ']' &&
          ch != '.' &&
          ch != ',' &&
          ch != ';' &&
          ch != ':' &&
          ch != '!' &&
          ch != '?' {
          out.write_char(' ')
        }
        pending_space = false
      }
      out.write_char(ch)
      has_text = true
      after_open_delimiter = ch == '(' || ch == '['
    }
  }
  out.to_string()
}
