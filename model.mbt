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
} derive(ToJson)

///|
pub extend SourceRecord with ToJson::{to_json}

///|
pub(all) struct Report {
  run_id : String?
  event_count : Int
  call_count : Int
  source_count : Int
  claim_count : Int
  sources : Array[SourceRecord]
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
}

///|
priv struct Claim {
  text : String
  source_ids : Array[String]
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
