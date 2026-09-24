///|
pub(all) struct Diagnostic {
  line : Int
  code : String
  message : String
} derive(ToJson)

///|
pub extend Diagnostic with ToJson::{to_json}

///|
pub(all) struct SourceRecord {
  id : String
  uri : String
  title : String?
  call_id : String
  line : Int
  content_present : Bool
} derive(ToJson)

///|
pub extend SourceRecord with ToJson::{to_json}

///|
pub(all) struct CitationEdge {
  claim_index : Int
  source_id : String
  call_id : String?
  line : Int
  evidence_status : String
} derive(ToJson)

///|
pub extend CitationEdge with ToJson::{to_json}

///|
pub(all) struct Report {
  run_id : String?
  event_count : Int
  call_count : Int
  source_count : Int
  claim_count : Int
  verified_citation_count : Int
  sources : Array[SourceRecord]
  citations : Array[CitationEdge]
  diagnostics : Array[Diagnostic]
} derive(ToJson)

///|
pub extend Report with ToJson::{to_json}

///|
pub fn Report::ok(self : Report) -> Bool {
  self.diagnostics.is_empty()
}

///|
priv struct Source {
  id : String
  uri : String
  title : String?
  content : String?
}

///|
priv struct Claim {
  citations : Array[ClaimCitation]
}

///|
priv struct ClaimCitation {
  source_id : String
  quote : String?
}

///|
priv enum Event {
  ToolCall(String, String, Int)
  ToolResult(String, String, Bool, Array[Source], Int)
  Answer(String, Array[Claim], Int)
}

///|
fn add_diagnostic(
  diagnostics : Array[Diagnostic],
  line : Int,
  code : String,
  message : String,
) -> Unit {
  diagnostics.push({ line, code, message, })
}
