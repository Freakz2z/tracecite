///|
priv struct DocumentCheckItem {
  document : String
  line : Int
  source : String
  kind : String
  status : String
  code : String
  message : String
  expected : String?
  actual : String?
  previous : String?
} derive(ToJson)

///|
priv struct DocumentCheckReport {
  document_count : Int
  checked_count : Int
  failed_count : Int
  warning_count : Int
  skipped_count : Int
  unbound_snippets : Int
  online : Bool
  items : Array[DocumentCheckItem]
} derive(ToJson)

///|
async fn document_command(
  args : Array[String],
  start : Int,
  initialize? : Bool = false,
) -> Int {
  let targets : Array[String] = []
  let excludes : Array[String] = []
  let mut root_arg = "."
  let mut snapshot_path : String? = None
  let mut baseline_path : String? = None
  let mut online_arg : Bool? = None
  let mut strict_arg : Bool? = None
  let mut config_arg = "tracecite.json"
  let mut config_explicit = false
  let mut use_config = true
  let mut json_output = false
  let mut github = false
  let mut index = start
  while index < args.length() {
    let option = args[index]
    if option == "--root" ||
      option == "--snapshot" ||
      option == "--baseline" ||
      option == "--config" ||
      option == "--exclude" {
      if index + 1 >= args.length() || args[index + 1].has_prefix("--") {
        @stdio.stderr.write("Missing value for \{option}\n")
        return 1
      }
      let value = args[index + 1]
      match option {
        "--root" => root_arg = value
        "--snapshot" => snapshot_path = Some(value)
        "--baseline" => baseline_path = Some(value)
        "--config" => {
          config_arg = value
          config_explicit = true
        }
        _ =>
          excludes.push(value.strip_prefix("./").unwrap_or(value[:]).to_owned())
      }
      index = index + 2
      continue
    }
    match option {
      "--online" => online_arg = Some(true)
      "--offline" => online_arg = Some(false)
      "--strict" => strict_arg = Some(true)
      "--no-strict" => strict_arg = Some(false)
      "--no-config" => use_config = false
      "--json" => json_output = true
      "--github" => github = true
      "--help" => {
        let command = if initialize { "init" } else { "check" }
        @stdio.stdout.write(
          "Usage: tracecite \{command} [file.md|directory ...] [--root directory]\n       [--config file.json | --no-config] [--online | --offline]\n       [--strict | --no-strict] [--json | --github] [--exclude path]\n       [--snapshot file.json] [--baseline file.json]\n\ncheck reads tracecite.json from the root when present. Explicit arguments override it.\ninit checks sources and creates a configuration plus baseline without replacing existing files.\n--snapshot ignores a configured baseline unless --baseline is also explicitly supplied.\n",
        )
        return 0
      }
      _ => {
        if option.has_prefix("-") {
          @stdio.stderr.write("Unknown option: \{option}\n")
          return 1
        }
        targets.push(option)
      }
    }
    index = index + 1
  }
  if json_output && github {
    @stdio.stderr.write("Use --json or --github separately\n")
    return 1
  }
  if !use_config && (config_explicit || initialize) {
    @stdio.stderr.write(
      "--no-config cannot be combined with --config or init\n",
    )
    return 1
  }
  if initialize && baseline_path is Some(_) {
    @stdio.stderr.write(
      "init creates a new baseline; use --snapshot to choose its path\n",
    )
    return 1
  }
  if initialize && snapshot_path is None {
    snapshot_path = Some(".tracecite-docs.json")
  }
  if snapshot_path is Some(path) && !path.to_lower().has_suffix(".json") {
    @stdio.stderr.write("Snapshot destination must end in .json\n")
    return 1
  }
  let root = @fs.realpath(root_arg) catch {
    _ => {
      @stdio.stderr.write("Cannot resolve root: \{root_arg}\n")
      return 1
    }
  }
  if @fs.kind(root) != Directory {
    @stdio.stderr.write("Root must be a directory\n")
    return 1
  }
  let mut project : @tracecite.DocumentProjectConfig? = None
  if !initialize && use_config {
    let config_path = root_join(root, config_arg)
    if config_explicit || @fs.exists(config_path) {
      let input = try {
        if @fs.file_size(config_path) <= 65_536 {
          @fs.read_file(config_path).text()
        } else {
          fail("configuration exceeds 64 KiB")
        }
      } catch {
        _ => {
          @stdio.stderr.write(
            "Cannot read project configuration: \{config_arg}\n",
          )
          return 1
        }
      }
      let parsed = @tracecite.parse_document_project_config(input)
      for diagnostic in parsed.diagnostics {
        @stdio.stderr.write(
          "\{config_arg}: [\{diagnostic.code}] \{diagnostic.message}\n",
        )
      }
      match parsed.config {
        Some(config) => project = Some(config)
        None => return 1
      }
    }
  }
  if project is Some(config) {
    if targets.is_empty() {
      for path in config.paths {
        targets.push(path)
      }
    }
    for path in config.exclude {
      excludes.push(path.strip_prefix("./").unwrap_or(path[:]).to_owned())
    }
    if baseline_path is None && snapshot_path is None {
      baseline_path = config.baseline
    }
  }
  let online = online_arg.unwrap_or(
    project.map(config => config.online).unwrap_or(false),
  )
  let strict = strict_arg.unwrap_or(
    project.map(config => config.strict).unwrap_or(initialize),
  )
  let mut init_config_path : String? = None
  if initialize {
    let config_path = document_creation_path(root, config_arg)
    let baseline_destination = document_creation_path(
      root,
      snapshot_path.unwrap(),
    )
    match (config_path, baseline_destination) {
      (Some(config), Some(snapshot)) if config != snapshot => {
        if @fs.exists(config) || @fs.exists(snapshot) {
          @stdio.stderr.write(
            "init will not replace an existing configuration or baseline\n",
          )
          return 1
        }
        init_config_path = Some(config)
        snapshot_path = Some(relative_document_path(root, snapshot))
      }
      _ => {
        @stdio.stderr.write(
          "init destinations must be distinct files inside the root with existing parent directories\n",
        )
        return 1
      }
    }
  }
  let mut baseline : @tracecite.DocumentSnapshot? = None
  if baseline_path is Some(path) {
    let input = @fs.read_file(root_join(root, path)).text() catch {
      _ => {
        @stdio.stderr.write("Cannot read baseline: \{path}\n")
        return 1
      }
    }
    let parsed : @tracecite.DocumentSnapshot = @json.from_json(
      @json.parse(input),
    ) catch {
      _ => {
        @stdio.stderr.write("Invalid document baseline: \{path}\n")
        return 1
      }
    }
    if parsed.version != 1 {
      @stdio.stderr.write("Unsupported baseline version\n")
      return 1
    }
    baseline = Some(parsed)
  }
  if targets.is_empty() {
    targets.push(".")
  }
  let paths : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for target in targets {
    collect_document_paths(root_join(root, target), root, excludes, paths, seen) catch {
      _ => {
        @stdio.stderr.write("Cannot scan document target: \{target}\n")
        return 1
      }
    }
  }
  if paths.is_empty() {
    @stdio.stderr.write("No Markdown documents found\n")
    return 1
  }
  let items : Array[DocumentCheckItem] = []
  let entries : Array[@tracecite.DocumentSnapshotEntry] = []
  let fetched : Map[String, RemoteFetch] = Map([])
  let mut unbound_snippets = 0
  let mut checked_count = 0
  for path in paths {
    let document = relative_document_path(root, path)
    if @fs.file_size(path) > 2_097_152 {
      items.push(
        document_problem(
          document, 1, "", "error", "DOCUMENT_TOO_LARGE", "document exceeds 2 MiB",
        ),
      )
      continue
    }
    let content = @fs.read_file(path).text() catch {
      _ => {
        items.push(
          document_problem(
            document, 1, "", "error", "DOCUMENT_UNAVAILABLE", "cannot read UTF-8 document",
          ),
        )
        continue
      }
    }
    let parsed = @tracecite.parse_document(content)
    unbound_snippets = unbound_snippets + parsed.unbound_snippets
    for diagnostic in parsed.diagnostics {
      items.push(
        document_problem(
          document,
          diagnostic.line,
          "",
          "error",
          diagnostic.code,
          diagnostic.message,
        ),
      )
    }
    for diagnostic in parsed.warnings {
      items.push(
        document_problem(
          document,
          diagnostic.line,
          "",
          "warning",
          diagnostic.code,
          diagnostic.message,
        ),
      )
    }
    for reference in parsed.references {
      let (source_path, raw_fragment) = split_document_source(reference.source)
      let fragment = decode_document_path(raw_fragment).unwrap_or(raw_fragment)
      let remote = source_path.has_prefix("https://") ||
        source_path.has_prefix("http://")
      if remote && !online {
        items.push(
          document_problem(
            document,
            reference.line,
            reference.source,
            "skipped",
            "WEB_SOURCE_SKIPPED",
            "web source not checked; use --online",
          ),
        )
        continue
      }
      if !remote && source_path.contains(":") {
        items.push(
          document_problem(
            document,
            reference.line,
            reference.source,
            "warning",
            "UNSUPPORTED_SOURCE_SCHEME",
            "use a relative file path or HTTP/HTTPS URL",
          ),
        )
        continue
      }
      if remote && reference.kind == "snippet" {
        items.push(
          document_problem(
            document,
            reference.line,
            reference.source,
            "warning",
            "UNSUPPORTED_REMOTE_SNIPPET",
            "source-bound code snippets currently require a local file",
          ),
        )
        continue
      }
      checked_count = checked_count + 1
      let result = if remote {
        match fetched.get(source_path) {
          Some(result) => result
          None => {
            let result = fetch_public_text(source_path)
            fetched.set(source_path, result)
            result
          }
        }
      } else {
        let decoded = decode_document_path(source_path)
        match decoded {
          None => remote_failure("INVALID_SOURCE_PATH")
          Some(decoded) => {
            let resolved = if decoded == "" {
              path
            } else {
              root_join(document_parent(path), decoded)
            }
            let canonical = @fs.realpath(resolved) catch { _ => "" }
            if canonical == "" {
              remote_failure("SOURCE_NOT_FOUND")
            } else if !inside_document_root(root, canonical) {
              remote_failure("SOURCE_OUTSIDE_ROOT")
            } else if @fs.kind(canonical) == Directory &&
              reference.excerpt is None &&
              fragment == "" {
              { ok: true, text: "", error_code: None, }
            } else if @fs.kind(canonical) != Regular {
              remote_failure("SOURCE_NOT_A_FILE")
            } else if reference.excerpt is None && fragment == "" {
              { ok: true, text: "", error_code: None, }
            } else {
              match fetched.get(canonical) {
                Some(result) => result
                None => {
                  let result = if @fs.file_size(canonical) > 2_097_152 {
                    remote_failure("SOURCE_TOO_LARGE")
                  } else {
                    let text = @fs.read_file(canonical).text() catch { _ => "" }
                    if text == "" {
                      remote_failure("SOURCE_EMPTY_OR_UNREADABLE")
                    } else {
                      { ok: true, text, error_code: None, }
                    }
                  }
                  fetched.set(canonical, result)
                  result
                }
              }
            }
          }
        }
      }
      if !result.ok {
        items.push(
          document_problem(
            document,
            reference.line,
            reference.source,
            "unavailable",
            result.error_code.unwrap_or("SOURCE_UNAVAILABLE"),
            "source cannot be independently read",
          ),
        )
        continue
      }
      let selection = if remote {
        @tracecite.SelectedSource::{ ok: true, text: result.text, code: "", }
      } else {
        @tracecite.select_document_source(result.text, fragment)
      }
      if !selection.ok {
        items.push(
          document_problem(
            document,
            reference.line,
            reference.source,
            "mismatch",
            selection.code,
            "referenced section or line range no longer exists",
          ),
        )
        continue
      }
      let matched = match reference.excerpt {
        Some(excerpt) =>
          @tracecite.document_excerpt_matches(
            selection.text,
            excerpt,
            reference.kind,
          )
        None => true
      }
      let observed = match reference.excerpt {
        Some(excerpt) =>
          if fragment != "" && !remote {
            selection.text
          } else {
            @tracecite.document_source_context(
              selection.text,
              excerpt,
              reference.kind,
            )
          }
        None => if !remote && fragment != "" { selection.text } else { "" }
      }
      let expected = reference.excerpt.map(@tracecite.bounded_document_text)
      if !matched {
        items.push({
          document,
          line: reference.line,
          source: reference.source,
          kind: reference.kind,
          status: "mismatch",
          code: "DOCUMENT_EXCERPT_MISMATCH",
          message: "document excerpt was not found in the selected source; review the candidate excerpt",
          expected,
          actual: Some(@tracecite.bounded_document_text(observed)),
          previous: None,
        })
        continue
      }
      let entry : @tracecite.DocumentSnapshotEntry = {
        document,
        source: reference.source,
        kind: reference.kind,
        excerpt: reference.excerpt,
        observed,
      }
      entries.push(entry)
      let mut previous : String? = None
      if baseline is Some(baseline) {
        for old in baseline.entries {
          if old.document == entry.document &&
            old.source == entry.source &&
            old.kind == entry.kind &&
            old.excerpt == entry.excerpt {
            previous = Some(old.observed)
            break
          }
        }
      }
      let (status, code, message) = match previous {
        Some(old) if old != observed =>
          (
            "changed", "REFERENCED_SOURCE_CHANGED", "referenced source context changed; review this document location",
          )
        None if baseline is Some(_) =>
          (
            "warning", "REFERENCE_NOT_IN_BASELINE", "new or edited reference; review before saving a new baseline",
          )
        _ => ("ok", "", "reference matches its current source")
      }
      items.push({
        document,
        line: reference.line,
        source: reference.source,
        kind: reference.kind,
        status,
        code,
        message,
        expected,
        actual: if status == "changed" {
          Some(@tracecite.bounded_document_text(observed))
        } else {
          None
        },
        previous: if status == "changed" {
          previous.map(@tracecite.bounded_document_text)
        } else {
          None
        },
      })
    }
  }
  let failed_count = items
    .filter(item => {
      item.status == "error" ||
      item.status == "mismatch" ||
      item.status == "unavailable" ||
      item.status == "changed"
    })
    .length()
  let warning_count = items.filter(item => item.status == "warning").length()
  let skipped_count = items.filter(item => item.status == "skipped").length()
  let report = DocumentCheckReport::{
    document_count: paths.length(),
    checked_count,
    failed_count,
    warning_count,
    skipped_count,
    unbound_snippets,
    online,
    items,
  }
  let passed = failed_count == 0 &&
    (!strict || warning_count == 0) &&
    checked_count > 0
  if json_output {
    @stdio.stdout.write(@json.to_json(report).stringify(indent=2) + "\n")
  } else {
    render_document_report(report, github)
  }
  if checked_count == 0 {
    @stdio.stderr.write("No checkable references; nothing has been verified\n")
  }
  if snapshot_path is Some(path) {
    if !passed || warning_count > 0 {
      @stdio.stderr.write(
        "Snapshot not written: resolve failed or unverified references first\n",
      )
      return 2
    }
    let snapshot = @tracecite.DocumentSnapshot::{ version: 1, entries, }
    let destination = root_join(root, path)
    let temporary = destination + ".tmp"
    if !write_new_document_file(
        temporary,
        @json.to_json(snapshot).stringify(indent=2) + "\n",
      ) {
      @stdio.stderr.write("Cannot write snapshot: \{path}\n")
      return 1
    }
    @fs.rename(temporary, destination, replace=!initialize) catch {
      _ => {
        @fs.remove(temporary) catch {
          _ => ()
        }
        @stdio.stderr.write("Cannot replace snapshot: \{path}\n")
        return 1
      }
    }
    if init_config_path is Some(config_path) {
      let portable_targets : Array[String] = []
      for target in targets {
        portable_targets.push(
          relative_document_path(root, @fs.realpath(root_join(root, target))),
        )
      }
      let config : @tracecite.DocumentProjectConfig = {
        version: 1,
        paths: portable_targets,
        exclude: excludes,
        baseline: Some(path),
        strict,
        online,
      }
      let content = @json.to_json(config).stringify(indent=2) + "\n"
      let validated = @tracecite.parse_document_project_config(content)
      if validated.config is None ||
        !write_new_document_file(config_path, content) {
        @fs.remove(destination) catch {
          _ => ()
        }
        @stdio.stderr.write(
          "Cannot create project configuration; new baseline removed\n",
        )
        return 1
      }
      @stdio.stderr.write(
        "Created project configuration: \{relative_document_path(root, config_path)}\n",
      )
    }
    @stdio.stderr.write(
      "Saved document snapshot: \{path} (\{entries.length()} references)\n",
    )
  }
  if passed {
    0
  } else {
    2
  }
}

///|
async fn document_creation_path(root : String, path : String) -> String? {
  let destination = root_join(root, path)
  let parent = @fs.realpath(document_parent(destination)) catch {
    _ => return None
  }
  let name = match destination.rev_split_once("/") {
    Some((_, name)) => name.to_owned()
    None => return None
  }
  if name == "" ||
    name == "." ||
    name == ".." ||
    !inside_document_root(root, parent) {
    None
  } else {
    Some(root_join(parent, name))
  }
}

///|
async fn write_new_document_file(path : String, content : String) -> Bool {
  let file = @fs.open(path, mode=WriteOnly, create_mode=CreateNew) catch {
    _ => return false
  }
  file.write(content) catch {
    _ => {
      file.close()
      @fs.remove(path) catch {
        _ => ()
      }
      return false
    }
  }
  file.close()
  true
}

///|
async fn collect_document_paths(
  path : String,
  root : String,
  excludes : Array[String],
  paths : Array[String],
  seen : Map[String, Bool],
) -> Unit {
  let canonical = @fs.realpath(path)
  if !inside_document_root(root, canonical) {
    fail("document target is outside root")
  }
  let relative = relative_document_path(root, canonical)
  if excludes.any(exclude => {
      exclude == "." ||
      relative == exclude ||
      relative.has_prefix(exclude + "/")
    }) {
    return
  }
  match @fs.kind(path, follow_symlink=false) {
    Directory =>
      for name in @fs.readdir(path, include_hidden=true, sort=true) {
        if [
            ".git", ".mooncakes", "_build", "target", "dist", "node_modules", ".venv",
            "__pycache__",
          ].contains(name) {
          continue
        }
        let child = root_join(path, name)
        if @fs.kind(child, follow_symlink=false) == SymLink {
          continue
        }
        collect_document_paths(child, root, excludes, paths, seen)
      }
    Regular | SymLink => {
      if !path.to_lower().has_suffix(".md") {
        return
      }
      if seen.get(canonical) is None {
        seen.set(canonical, true)
        paths.push(canonical)
      }
    }
    _ => ()
  }
}

///|
fn inside_document_root(root : String, path : String) -> Bool {
  path == root || path.has_prefix(if root == "/" { root } else { root + "/" })
}

///|
fn relative_document_path(root : String, path : String) -> String {
  if path == root {
    "."
  } else {
    path
    .strip_prefix(if root == "/" { root } else { root + "/" })
    .unwrap_or(path[:])
    .to_owned()
  }
}

///|
fn root_join(root : String, path : String) -> String {
  if path.has_prefix("/") {
    path
  } else {
    root + "/" + path
  }
}

///|
fn document_parent(path : String) -> String {
  match path.rev_split_once("/") {
    Some((parent, _)) => if parent == "" { "/" } else { parent.to_owned() }
    None => "."
  }
}

///|
fn split_document_source(source : String) -> (String, String) {
  match source.split_once("#") {
    Some((path, fragment)) => (path.to_owned(), fragment.to_owned())
    None => (source, "")
  }
}

///|
fn decode_document_path(path : String) -> String? {
  let encoded = @utf8.encode(path)
  let bytes : Array[Byte] = []
  let mut index = 0
  while index < encoded.length() {
    if encoded[index] == b'%' {
      if index + 2 >= encoded.length() {
        return None
      }
      let first = hex_digit(encoded[index + 1])
      let last = hex_digit(encoded[index + 2])
      if first < 0 || last < 0 {
        return None
      }
      bytes.push((first * 16 + last).to_byte())
      index = index + 3
    } else {
      bytes.push(encoded[index])
      index = index + 1
    }
  }
  Some(@utf8.decode(Bytes::from_array(bytes[:]))) catch {
    _ => None
  }
}

///|
fn hex_digit(byte : Byte) -> Int {
  if byte >= b'0' && byte <= b'9' {
    byte.to_int() - b'0'.to_int()
  } else if byte >= b'a' && byte <= b'f' {
    byte.to_int() - b'a'.to_int() + 10
  } else if byte >= b'A' && byte <= b'F' {
    byte.to_int() - b'A'.to_int() + 10
  } else {
    -1
  }
}

///|
fn document_problem(
  document : String,
  line : Int,
  source : String,
  status : String,
  code : String,
  message : String,
) -> DocumentCheckItem {
  {
    document,
    line,
    source,
    kind: "diagnostic",
    status,
    code,
    message,
    expected: None,
    actual: None,
    previous: None,
  }
}

///|
async fn render_document_report(
  report : DocumentCheckReport,
  github : Bool,
) -> Unit {
  let status = if report.failed_count > 0 {
    "FAIL"
  } else if report.checked_count == 0 {
    "NO_CHECKS"
  } else if report.warning_count > 0 {
    "REVIEW"
  } else if report.online {
    "OK"
  } else {
    "LOCAL_OK"
  }
  @stdio.stdout.write(
    "\{status}: \{report.document_count} documents; \{report.checked_count} references checked, \{report.failed_count} failed, \{report.warning_count} need review\n",
  )
  @stdio.stdout.write(
    "Coverage: \{report.skipped_count} web references skipped; \{report.unbound_snippets} code blocks without source= (not checked)\n",
  )
  for item in report.items {
    if item.status == "skipped" || item.status == "ok" {
      continue
    }
    @stdio.stdout.write(
      "  \{item.document}:\{item.line} [\{item.code}] \{item.source}\n    \{item.message}\n",
    )
    if item.expected is Some(expected) {
      render_document_excerpt("document excerpt", expected)
    }
    if item.previous is Some(previous) {
      render_document_excerpt("previously observed", previous)
    }
    if item.actual is Some(actual) {
      render_document_excerpt("current source candidate", actual)
    }
    if github {
      let level = if item.status == "warning" { "warning" } else { "error" }
      @stdio.stdout.write(
        "::\{level} file=\{github_escape(item.document, property=true)},line=\{item.line},title=\{github_escape(item.code, property=true)}::\{github_escape(item.message + " (" + item.source + ")")}\n",
      )
    }
  }
}

///|
async fn render_document_excerpt(label : String, text : String) -> Unit {
  @stdio.stdout.write("    \{label}:\n")
  for line in text.split("\n") {
    @stdio.stdout.write("      | \{line}\n")
  }
}

///|
fn github_escape(text : String, property? : Bool = false) -> String {
  let text = text
    .replace_all(old="%", new="%25")
    .replace_all(old="\r", new="%0D")
    .replace_all(old="\n", new="%0A")
  if property {
    text.replace_all(old=",", new="%2C").replace_all(old=":", new="%3A")
  } else {
    text
  }
}
