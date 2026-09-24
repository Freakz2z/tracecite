///|
fn has_code(report : Report, code : String) -> Bool {
  for diagnostic in report.diagnostics {
    if diagnostic.code == code {
      return true
    }
  }
  false
}

///|
test "valid trace links cited source to successful call" {
  let input =
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"search"}
    #|{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"https://example.org/a"}]}
    #|{"type":"answer","run_id":"r1","claims":[{"text":"A","source_ids":["s1"]}]}
  let report = validate_jsonl(input)
  assert_true(report.ok())
  assert_eq(report.event_count, 3)
  assert_eq(report.call_count, 1)
  assert_eq(report.source_count, 1)
  assert_eq(report.claim_count, 1)
  assert_eq(report.sources[0].call_id, "c1")
  assert_eq(report.citations.length(), 1)
  assert_eq(report.citations[0].claim_index, 1)
  assert_eq(report.citations[0].source_id, "s1")
  assert_eq(report.citations[0].call_id, Some("c1"))
}

///|
test "answer cannot cite a missing source" {
  let input =
    #|{"type":"answer","run_id":"r1","claims":[{"text":"A","source_ids":["missing"]}]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "UNKNOWN_SOURCE"))
  assert_eq(report.diagnostics[0].line, 1)
  assert_eq(report.citations[0].call_id, None)
}

///|
test "diagnostic does not echo claim content" {
  let input =
    #|{"type":"answer","run_id":"r1","claims":[{"text":"private user statement","source_ids":["missing"]}]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "UNKNOWN_SOURCE"))
  assert_false(report.diagnostics[0].message.contains("private user statement"))
}

///|
test "failed tool result never establishes provenance" {
  let input =
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"search"}
    #|{"type":"tool_result","run_id":"r1","call_id":"c1","ok":false,"sources":[{"id":"s1","uri":"https://example.org/a"}]}
    #|{"type":"answer","run_id":"r1","claims":[{"text":"A","source_ids":["s1"]}]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "SOURCE_ON_FAILED_RESULT"))
  assert_true(has_code(report, "UNKNOWN_SOURCE"))
  assert_eq(report.source_count, 0)
}

///|
test "orphan result cannot introduce sources" {
  let input =
    #|{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"https://example.org/a"}]}
    #|{"type":"answer","run_id":"r1","claims":[{"text":"A","source_ids":["s1"]}]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "ORPHAN_RESULT"))
  assert_true(has_code(report, "UNKNOWN_SOURCE"))
}

///|
test "duplicate source keeps first provenance" {
  let input =
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"search"}
    #|{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"https://example.org/a"}]}
    #|{"type":"tool_call","run_id":"r1","call_id":"c2","tool":"search"}
    #|{"type":"tool_result","run_id":"r1","call_id":"c2","ok":true,"sources":[{"id":"s1","uri":"https://example.org/b"}]}
    #|{"type":"answer","run_id":"r1","claims":[{"text":"A","source_ids":["s1"]}]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "DUPLICATE_SOURCE"))
  assert_eq(report.source_count, 1)
  assert_eq(report.sources[0].uri, "https://example.org/a")
}

///|
test "duplicate call and result are rejected" {
  let input =
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"search"}
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"search"}
    #|{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true}
    #|{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true}
    #|{"type":"answer","run_id":"r1","claims":[]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "DUPLICATE_CALL"))
  assert_true(has_code(report, "DUPLICATE_RESULT"))
}

///|
test "call without result is reported" {
  let input =
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"search"}
    #|{"type":"answer","run_id":"r1","claims":[]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "MISSING_RESULT"))
}

///|
test "mixed run id cannot lend sources" {
  let input =
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"search"}
    #|{"type":"tool_result","run_id":"r2","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"https://example.org/a"}]}
    #|{"type":"answer","run_id":"r1","claims":[{"text":"A","source_ids":["s1"]}]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "RUN_MISMATCH"))
  assert_true(has_code(report, "MISSING_RESULT"))
  assert_true(has_code(report, "UNKNOWN_SOURCE"))
}

///|
test "malformed lines and invalid fields are reported" {
  let input =
    #|not json
    #|{"type":"tool_call","run_id":"r1","call_id":"","tool":"search"}
    #|{"type":"answer","run_id":"r1","claims":[]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "INVALID_JSON"))
  assert_true(has_code(report, "INVALID_FIELD"))
}

///|
test "answer is final and unique" {
  let input =
    #|{"type":"answer","run_id":"r1","claims":[]}
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"search"}
    #|{"type":"answer","run_id":"r1","claims":[]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "EVENT_AFTER_ANSWER"))
  assert_true(has_code(report, "DUPLICATE_ANSWER"))
}

///|
test "empty trace is invalid" {
  let report = validate_jsonl("\n \n")
  assert_true(has_code(report, "EMPTY_TRACE"))
}

///|
test "evidence mode matches exact quote to observed content" {
  let input =
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"read"}
    #|{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"file:///a","content":"value=42\n"}]}
    #|{"type":"answer","run_id":"r1","claims":[{"text":"value=42","citations":[{"source_id":"s1","quote":"value=42"}]}]}
  let report = validate_evidence_jsonl(input)
  assert_true(report.ok())
  assert_eq(report.verified_citation_count, 1)
  assert_eq(report.citations[0].evidence_status, "matched")
}

///|
test "evidence mode rejects fabricated quote and legacy ID only citation" {
  let false_quote =
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"read"}
    #|{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"file:///a","content":"value=42"}]}
    #|{"type":"answer","run_id":"r1","claims":[{"text":"value=99","citations":[{"source_id":"s1","quote":"value=99"}]}]}
  assert_true(
    has_code(validate_evidence_jsonl(false_quote), "QUOTE_NOT_IN_SOURCE"),
  )
  let legacy =
    #|{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"read"}
    #|{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"file:///a"}]}
    #|{"type":"answer","run_id":"r1","claims":[{"text":"A","source_ids":["s1"]}]}
  let report = validate_evidence_jsonl(legacy)
  assert_true(has_code(report, "MISSING_SOURCE_CONTENT"))
  assert_true(has_code(report, "MISSING_QUOTE"))
}

///|
test "compare reports content change across valid runs" {
  let old_input =
    #|{"type":"tool_call","run_id":"old","call_id":"c1","tool":"read"}
    #|{"type":"tool_result","run_id":"old","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"file:///a","content":"value=42"}]}
    #|{"type":"answer","run_id":"old","claims":[{"text":"A","citations":[{"source_id":"s1","quote":"value=42"}]}]}
  let new_input =
    #|{"type":"tool_call","run_id":"new","call_id":"c1","tool":"read"}
    #|{"type":"tool_result","run_id":"new","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"file:///a","content":"value=43"}]}
    #|{"type":"answer","run_id":"new","claims":[{"text":"A","citations":[{"source_id":"s1","quote":"value=43"}]}]}
  let drift = compare_jsonl(old_input, new_input)
  assert_true(drift.old_valid && drift.new_valid)
  assert_eq(drift.changes.length(), 1)
  assert_eq(drift.changes[0].kind, "changed")
  assert_eq(drift.changes[0].uri, "file:///a")
  assert_false(drift.ok())
  assert_true(compare_jsonl(old_input, old_input).ok())
}

///|
test "evidence mode cannot pass an uncited answer" {
  let input =
    #|{"type":"answer","run_id":"r1","claims":[{"text":"unsupported","citations":[]}]}
  assert_true(has_code(validate_evidence_jsonl(input), "UNCITED_CLAIM"))
  let empty =
    #|{"type":"answer","run_id":"r1","claims":[]}
  assert_true(has_code(validate_evidence_jsonl(empty), "EMPTY_ANSWER"))
}
