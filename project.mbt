///|
/// Portable project settings shared by local checks and CI. Paths are relative
/// to the explicit workspace root, never to the process running the CLI.
pub(all) struct DocumentProjectConfig {
  version : Int
  paths : Array[String]
  exclude : Array[String]
  baseline : String?
  strict : Bool
  online : Bool
} derive(ToJson)

///|
pub extend DocumentProjectConfig with ToJson::{to_json}

///|
pub(all) struct DocumentProjectConfigResult {
  config : DocumentProjectConfig?
  diagnostics : Array[Diagnostic]
} derive(ToJson)

///|
pub extend DocumentProjectConfigResult with ToJson::{to_json}

///|
/// Read version 1 project configuration. Reject misspelled keys and malformed
/// values so a broken configuration cannot silently widen the scan or disable
/// strict checks. New configurations default to strict, offline checks.
pub fn parse_document_project_config(
  input : String,
) -> DocumentProjectConfigResult {
  let diagnostics : Array[Diagnostic] = []
  let value = @json.parse(input) catch {
    _ => {
      add_diagnostic(
        diagnostics, 1, "INVALID_PROJECT_CONFIG", "configuration must be valid JSON",
      )
      return { config: None, diagnostics, }
    }
  }
  if value is Object(object) {
    for key, _ in object {
      if !["version", "paths", "exclude", "baseline", "strict", "online"].contains(
          key,
        ) {
        add_diagnostic(
          diagnostics,
          1,
          "UNKNOWN_CONFIG_FIELD",
          "unknown configuration field: " + key,
        )
      }
    }
  } else {
    add_diagnostic(
      diagnostics, 1, "INVALID_PROJECT_CONFIG", "configuration must be an object",
    )
    return { config: None, diagnostics, }
  }
  match field(value, "version") {
    Some(Number(version, ..)) if version == 1.0 => ()
    _ =>
      add_diagnostic(
        diagnostics, 1, "UNSUPPORTED_CONFIG_VERSION", "configuration requires version: 1",
      )
  }
  let paths = document_config_paths(value, "paths", ["."], false, diagnostics)
  let exclude = document_config_paths(value, "exclude", [], true, diagnostics)
  let baseline = match field(value, "baseline") {
    None => None
    Some(Null) => None
    Some(String(path)) if valid_document_config_path(path) &&
      path.to_lower().has_suffix(".json") => Some(path)
    _ => {
      add_diagnostic(
        diagnostics, 1, "INVALID_CONFIG_BASELINE", "baseline must be a root-relative .json file path",
      )
      None
    }
  }
  let strict = document_config_bool(value, "strict", true, diagnostics)
  let online = document_config_bool(value, "online", false, diagnostics)
  {
    config: if diagnostics.is_empty() {
      Some({ version: 1, paths, exclude, baseline, strict, online, })
    } else {
      None
    },
    diagnostics,
  }
}

///|
fn document_config_bool(
  value : Json,
  key : String,
  default : Bool,
  diagnostics : Array[Diagnostic],
) -> Bool {
  match field(value, key) {
    None => default
    Some(True) => true
    Some(False) => false
    _ => {
      add_diagnostic(
        diagnostics,
        1,
        "INVALID_CONFIG_FIELD",
        "expected boolean: " + key,
      )
      default
    }
  }
}

///|
fn document_config_paths(
  value : Json,
  key : String,
  default : Array[String],
  allow_empty : Bool,
  diagnostics : Array[Diagnostic],
) -> Array[String] {
  match field(value, key) {
    None => default
    Some(Array(items)) => {
      let paths : Array[String] = []
      for item in items {
        if item is String(path) && valid_document_config_path(path) {
          paths.push(normalize_document_config_path(path))
        } else {
          add_diagnostic(
            diagnostics,
            1,
            "INVALID_CONFIG_PATH",
            "expected a nonempty root-relative path in " + key,
          )
        }
      }
      if paths.is_empty() && !allow_empty {
        add_diagnostic(
          diagnostics, 1, "EMPTY_CONFIG_PATHS", "paths must contain at least one scan target",
        )
      }
      paths
    }
    _ => {
      add_diagnostic(
        diagnostics,
        1,
        "INVALID_CONFIG_FIELD",
        "expected an array of paths: " + key,
      )
      []
    }
  }
}

///|
fn valid_document_config_path(path : String) -> Bool {
  if path.trim() == "" ||
    path.has_prefix("/") ||
    path.contains("\\") ||
    path.contains(":") ||
    path.contains("\n") ||
    path.contains("\r") {
    return false
  }
  let mut depth = 0
  for part in path.split("/") {
    if part == ".." {
      if depth == 0 {
        return false
      }
      depth = depth - 1
    } else if part != "" && part != "." {
      depth = depth + 1
    }
  }
  true
}

///|
fn normalize_document_config_path(path : String) -> String {
  let parts : Array[String] = []
  for part in path.split("/") {
    if part == ".." {
      ignore(parts.pop())
    } else if part != "" && part != "." {
      parts.push(part.to_owned())
    }
  }
  if parts.is_empty() {
    "."
  } else {
    parts.join("/")
  }
}
