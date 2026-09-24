///|
/// Exit codes: 0 for a valid trace, 1 for usage or I/O failure, 2 for a trace
/// with structural diagnostics.
#cfg(target="native")
extern "c" fn process_exit(code : Int) = "exit"

///|
async fn main {
  let args = @env.args()
  let mut index = 1
  if args.length() > 1 && args[1] == "--" {
    index = 2
  }
  if args.length() <= index {
    @stdio.stderr.write(
      "Usage: tracecite <trace.jsonl> [--evidence] [--json] | compare <old.jsonl> <new.jsonl> [--json] | verify-files <trace.jsonl>\n",
    )
    process_exit(1)
    return
  }
  if args[index] == "verify-files" {
    if args.length() != index + 2 {
      @stdio.stderr.write("Usage: tracecite verify-files <trace.jsonl>\n")
      process_exit(1)
      return
    }
    let trace_path = args[index + 1]
    let input = @fs.read_file(trace_path).text() catch {
      error => {
        @stdio.stderr.write("Cannot read \{trace_path}: \{error}\n")
        process_exit(1)
        return
      }
    }
    let report = @tracecite.validate_evidence_jsonl(input)
    if !report.ok() {
      for diagnostic in report.diagnostics {
        @stdio.stdout.write(
          "  line \{diagnostic.line} [\{diagnostic.code}] \{diagnostic.message}\n",
        )
      }
      process_exit(2)
      return
    }
    for source in report.sources {
      let file_path = match source.uri.strip_prefix("file://") {
        Some(path) => path.to_owned()
        None =>
          match source.uri.strip_prefix("file:") {
            Some(path) => path.to_owned()
            None => {
              @stdio.stdout.write("[UNSUPPORTED_SOURCE_URI] \{source.uri}\n")
              process_exit(2)
              return
            }
          }
      }
      let live_content = @fs.read_file(file_path).text() catch {
        error => {
          @stdio.stdout.write("[SOURCE_UNAVAILABLE] \{source.uri}: \{error}\n")
          process_exit(2)
          return
        }
      }
      if !@tracecite.source_snapshot_matches(input, source.uri, live_content) {
        @stdio.stdout.write("[SOURCE_FILE_MISMATCH] \{source.uri}\n")
        process_exit(2)
        return
      }
    }
    @stdio.stdout.write(
      "PASS: \{report.source_count} source files match captured content\n",
    )
    return
  }
  if args[index] == "compare" {
    if args.length() != index + 3 && args.length() != index + 4 {
      @stdio.stderr.write(
        "Usage: tracecite compare <old.jsonl> <new.jsonl> [--json]\n",
      )
      process_exit(1)
      return
    }
    let json_output = args.length() == index + 4 && args[index + 3] == "--json"
    if args.length() == index + 4 && !json_output {
      @stdio.stderr.write("Unknown option: \{args[index + 3]}\n")
      process_exit(1)
      return
    }
    let old_path = args[index + 1]
    let new_path = args[index + 2]
    let old_input = @fs.read_file(old_path).text() catch {
      error => {
        @stdio.stderr.write("Cannot read \{old_path}: \{error}\n")
        process_exit(1)
        return
      }
    }
    let new_input = @fs.read_file(new_path).text() catch {
      error => {
        @stdio.stderr.write("Cannot read \{new_path}: \{error}\n")
        process_exit(1)
        return
      }
    }
    let drift = @tracecite.compare_jsonl(old_input, new_input)
    if json_output {
      @stdio.stdout.write(@json.to_json(drift).stringify(indent=2) + "\n")
    } else if drift.old_valid && drift.new_valid {
      @stdio.stdout.write(
        "\{drift.changes.length()} source changes; \{drift.unchanged_count} unchanged\n",
      )
      for change in drift.changes {
        @stdio.stdout.write("  [\{change.kind}] \{change.uri}\n")
      }
    } else {
      @stdio.stdout.write("Cannot compare: input evidence validation failed\n")
      for diagnostic in drift.old_diagnostics {
        @stdio.stdout.write(
          "  old line \{diagnostic.line} [\{diagnostic.code}] \{diagnostic.message}\n",
        )
      }
      for diagnostic in drift.new_diagnostics {
        @stdio.stdout.write(
          "  new line \{diagnostic.line} [\{diagnostic.code}] \{diagnostic.message}\n",
        )
      }
    }
    if !drift.ok() {
      process_exit(2)
    }
    return
  }
  if args.length() > index + 3 {
    @stdio.stderr.write(
      "Usage: tracecite <trace.jsonl> [--evidence] [--json]\n",
    )
    process_exit(1)
    return
  }
  let path = args[index]
  let mut json_output = false
  let mut require_evidence = false
  for i = index + 1; i < args.length(); i = i + 1 {
    match args[i] {
      "--json" => json_output = true
      "--evidence" => require_evidence = true
      option => {
        @stdio.stderr.write("Unknown option: \{option}\n")
        process_exit(1)
        return
      }
    }
  }
  let input = @fs.read_file(path).text() catch {
    error => {
      @stdio.stderr.write("Cannot read \{path}: \{error}\n")
      process_exit(1)
      return
    }
  }
  let report = if require_evidence {
    @tracecite.validate_evidence_jsonl(input)
  } else {
    @tracecite.validate_jsonl(input)
  }
  if json_output {
    @stdio.stdout.write(@json.to_json(report).stringify(indent=2) + "\n")
  } else {
    let run_id = match report.run_id {
      Some(id) => id
      None => "(unknown)"
    }
    if report.ok() {
      @stdio.stdout.write(
        "PASS \{run_id}: \{report.event_count} events, \{report.call_count} calls, \{report.source_count} sources, \{report.claim_count} claims, \{report.verified_citation_count}/\{report.citations.length()} matched citations\n",
      )
    } else {
      @stdio.stdout.write(
        "FAIL \{run_id}: \{report.diagnostics.length()} diagnostics\n",
      )
      for diagnostic in report.diagnostics {
        @stdio.stdout.write(
          "  line \{diagnostic.line} [\{diagnostic.code}] \{diagnostic.message}\n",
        )
      }
    }
  }
  if !report.ok() {
    process_exit(2)
  }
}
