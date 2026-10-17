///|
/// An edit block in the saved/current observation, not in the original file.
/// Starts are one-based; a zero count denotes an insertion/deletion position.
pub(all) struct DocumentSourceDiffHunk {
  previous_start_line : Int32
  previous_line_count : Int32
  current_start_line : Int32
  current_line_count : Int32
  previous_text : String
  current_text : String
  text_truncated : Bool
} derive(ToJson)

///|
pub extend DocumentSourceDiffHunk with ToJson::{to_json}

///|
/// complete describes edit computation; display_truncated describes presentation.
/// Counts are absent when the bounded computation cannot finish.
pub(all) struct DocumentSourceDiff {
  algorithm : String
  coordinate_system : String
  complete : Bool
  reason : String?
  previous_line_count : Int32?
  current_line_count : Int32?
  added_lines : Int32?
  removed_lines : Int32?
  total_hunks : Int32?
  hunks : Array[DocumentSourceDiffHunk]
  display_truncated : Bool
} derive(ToJson)

///|
pub extend DocumentSourceDiff with ToJson::{to_json}

///|
fn source_diff_unavailable(
  reason : String,
  previous_line_count : Int32?,
  current_line_count : Int32?,
) -> DocumentSourceDiff {
  {
    algorithm: "bounded_lcs_lines_v1",
    coordinate_system: "observed_source_1_based",
    complete: false,
    reason: Some(reason),
    previous_line_count,
    current_line_count,
    added_lines: None,
    removed_lines: None,
    total_hunks: None,
    hunks: [],
    display_truncated: false,
  }
}

///|
// Preserve line endings, including CRLF and the presence of a final newline.
fn source_diff_lines(text : String) -> Array[String] {
  if text == "" {
    return []
  }
  let lines = text.split("\n").map(line => line.to_owned()).to_array()
  for index = 0; index + 1 < lines.length(); index = index + 1 {
    lines[index] = lines[index] + "\n"
  }
  if lines[lines.length() - 1] == "" {
    let _ = lines.pop()
  }
  lines
}

///|
fn source_diff_display(text : String) -> (String, Bool) {
  let chars = text.to_array()
  if chars.length() <= 512 {
    (text, false)
  } else {
    (String::from_array(chars[:512]) + "\n…", true)
  }
}

///|
/// Compute a shortest insertion/deletion script over exact lines, with stable
/// deletion-first tie breaking. Shared prefix/suffix lines are removed before
/// allocating the LCS table. Limits: 262144 UTF-16 units and 16384 lines per
/// input; 262144 table cells. Emit at most 20 hunks and 512 Unicode characters
/// per hunk side, plus an omission marker. This never changes verification or
/// baseline acceptance; incomplete analysis must not be treated as no change.
pub fn diff_document_source(
  previous : String,
  current : String,
) -> DocumentSourceDiff {
  if previous.length() > 262144 || current.length() > 262144 {
    return source_diff_unavailable("input_limit", None, None)
  }
  let before = source_diff_lines(previous)
  let after = source_diff_lines(current)
  let before_count = Some(before.length())
  let after_count = Some(after.length())
  if before.length() > 16384 || after.length() > 16384 {
    return source_diff_unavailable("line_limit", before_count, after_count)
  }
  let mut prefix = 0
  while prefix < before.length() &&
        prefix < after.length() &&
        before[prefix] == after[prefix] {
    prefix += 1
  }
  let mut suffix = 0
  while suffix < before.length() - prefix &&
        suffix < after.length() - prefix &&
        before[before.length() - suffix - 1] ==
        after[after.length() - suffix - 1] {
    suffix += 1
  }
  let n = before.length() - prefix - suffix
  let m = after.length() - prefix - suffix
  let width = m + 1
  if n + 1 > 262144 / width {
    return source_diff_unavailable("cell_limit", before_count, after_count)
  }
  let table : Array[Int32] = Array::make((n + 1) * width, 0)
  for i = n - 1; i >= 0; i = i - 1 {
    for j = m - 1; j >= 0; j = j - 1 {
      table[i * width + j] = if before[prefix + i] == after[prefix + j] {
        1 + table[(i + 1) * width + j + 1]
      } else {
        Int32::max(table[(i + 1) * width + j], table[i * width + j + 1])
      }
    }
  }
  let hunks : Array[DocumentSourceDiffHunk] = []
  let mut i = 0
  let mut j = 0
  let mut added = 0
  let mut removed = 0
  let mut total_hunks = 0
  let mut display_truncated = false
  while i < n || j < m {
    if i < n && j < m && before[prefix + i] == after[prefix + j] {
      i += 1
      j += 1
      continue
    }
    let first_i = i
    let first_j = j
    while i < n || j < m {
      if i < n && j < m && before[prefix + i] == after[prefix + j] {
        break
      }
      if i < n &&
        (j == m || table[(i + 1) * width + j] >= table[i * width + j + 1]) {
        i += 1
      } else {
        j += 1
      }
    }
    total_hunks += 1
    removed += i - first_i
    added += j - first_j
    if hunks.length() < 20 {
      let (previous_text, old_cut) = source_diff_display(
        before[prefix + first_i:prefix + i].join(""),
      )
      let (current_text, new_cut) = source_diff_display(
        after[prefix + first_j:prefix + j].join(""),
      )
      hunks.push({
        previous_start_line: prefix + first_i + 1,
        previous_line_count: i - first_i,
        current_start_line: prefix + first_j + 1,
        current_line_count: j - first_j,
        previous_text,
        current_text,
        text_truncated: old_cut || new_cut,
      })
      display_truncated = display_truncated || old_cut || new_cut
    } else {
      display_truncated = true
    }
  }
  {
    algorithm: "bounded_lcs_lines_v1",
    coordinate_system: "observed_source_1_based",
    complete: true,
    reason: None,
    previous_line_count: before_count,
    current_line_count: after_count,
    added_lines: Some(added),
    removed_lines: Some(removed),
    total_hunks: Some(total_hunks),
    hunks,
    display_truncated,
  }
}
