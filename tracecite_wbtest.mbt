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
}

///|
test "answer cannot cite a missing source" {
  let input =
    #|{"type":"answer","run_id":"r1","claims":[{"text":"A","source_ids":["missing"]}]}
  let report = validate_jsonl(input)
  assert_true(has_code(report, "UNKNOWN_SOURCE"))
  assert_eq(report.diagnostics[0].line, 1)
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
