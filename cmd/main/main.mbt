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
  if args.length() <= index || args.length() > index + 2 {
    @stdio.stderr.write("Usage: tracecite <trace.jsonl> [--json]\n")
    process_exit(1)
    return
  }
  let path = args[index]
  let json_output = args.length() == index + 2 && args[index + 1] == "--json"
  if args.length() == index + 2 && !json_output {
    @stdio.stderr.write("Unknown option: \{args[index + 1]}\n")
    process_exit(1)
    return
  }
  let input = @fs.read_file(path).text() catch {
    error => {
      @stdio.stderr.write("Cannot read \{path}: \{error}\n")
      process_exit(1)
      return
    }
  }
  let report = @tracecite.validate_jsonl(input)
  if json_output {
    @stdio.stdout.write(@json.to_json(report).stringify(indent=2) + "\n")
  } else {
    let run_id = match report.run_id {
      Some(id) => id
      None => "(unknown)"
    }
    if report.ok() {
      @stdio.stdout.write(
        "PASS \{run_id}: \{report.event_count} events, \{report.call_count} calls, \{report.source_count} sources, \{report.claim_count} claims\n",
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
