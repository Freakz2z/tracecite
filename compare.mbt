///|
pub(all) struct SourceChange {
  kind : String
  uri : String
} derive(ToJson)

///|
pub extend SourceChange with ToJson::{to_json}

///|
pub(all) struct DriftReport {
  old_run_id : String?
  new_run_id : String?
  old_valid : Bool
  new_valid : Bool
  unchanged_count : Int
  changes : Array[SourceChange]
  old_diagnostics : Array[Diagnostic]
  new_diagnostics : Array[Diagnostic]
} derive(ToJson)

///|
pub extend DriftReport with ToJson::{to_json}

///|
pub fn DriftReport::ok(self : DriftReport) -> Bool {
  self.old_valid && self.new_valid && self.changes.is_empty()
}

///|
/// Compare captured source content by stable URI across two valid runs.
/// Changes are reported without echoing source text.
pub fn compare_jsonl(old_input : String, new_input : String) -> DriftReport {
  let old_report = validate_evidence_jsonl(old_input)
  let new_report = validate_evidence_jsonl(new_input)
  let changes : Array[SourceChange] = []
  let mut unchanged_count = 0
  if old_report.ok() && new_report.ok() {
    let old_contents : Map[String, String] = Map([])
    let new_contents : Map[String, String] = Map([])
    let old_events = parse_jsonl(old_input, [])
    let new_events = parse_jsonl(new_input, [])
    for event in old_events {
      if event is ToolResult(_, _, true, sources, _) {
        for source in sources {
          if source.content is Some(content) {
            old_contents.set(source.uri, content)
          }
        }
      }
    }
    for event in new_events {
      if event is ToolResult(_, _, true, sources, _) {
        for source in sources {
          if source.content is Some(content) {
            new_contents.set(source.uri, content)
          }
        }
      }
    }
    for source in old_report.sources {
      match new_contents.get(source.uri) {
        None => changes.push({ kind: "removed", uri: source.uri, })
        Some(new_content) =>
          match old_contents.get(source.uri) {
            Some(old_content) if old_content == new_content =>
              unchanged_count = unchanged_count + 1
            _ => changes.push({ kind: "changed", uri: source.uri, })
          }
      }
    }
    for source in new_report.sources {
      if old_contents.get(source.uri) is None {
        changes.push({ kind: "added", uri: source.uri, })
      }
    }
  }
  {
    old_run_id: old_report.run_id,
    new_run_id: new_report.run_id,
    old_valid: old_report.ok(),
    new_valid: new_report.ok(),
    unchanged_count,
    changes,
    old_diagnostics: old_report.diagnostics,
    new_diagnostics: new_report.diagnostics,
  }
}
