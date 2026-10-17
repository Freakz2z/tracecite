///|
test "line diff locates separated Unicode changes in observation coordinates" {
  let diff = diff_document_source(
    "标题\n旧值\nkeep\n原权限\n", "标题\n新值\nkeep\n新权限\n",
  )
  assert_true(diff.complete)
  assert_false(diff.display_truncated)
  assert_eq(diff.total_hunks, Some(2))
  assert_eq(diff.added_lines, Some(2))
  assert_eq(diff.removed_lines, Some(2))
  assert_eq(diff.hunks[0].previous_start_line, 2)
  assert_eq(diff.hunks[0].current_start_line, 2)
  assert_eq(diff.hunks[0].previous_text, "旧值\n")
  assert_eq(diff.hunks[1].previous_start_line, 4)
  assert_eq(diff.hunks[1].current_text, "新权限\n")
  assert_eq(diff.coordinate_system, "observed_source_1_based")
}

///|
test "line diff preserves empty sources newline identity and insertion positions" {
  let empty = diff_document_source("", "")
  assert_eq(empty.previous_line_count, Some(0))
  assert_eq(empty.total_hunks, Some(0))
  let inserted = diff_document_source("", "first\n")
  assert_eq(inserted.hunks[0].previous_start_line, 1)
  assert_eq(inserted.hunks[0].previous_line_count, 0)
  assert_eq(inserted.hunks[0].current_text, "first\n")
  let deleted = diff_document_source("last", "")
  assert_eq(deleted.hunks[0].current_line_count, 0)
  assert_eq(deleted.hunks[0].previous_text, "last")
  let tail = diff_document_source("first\n", "first\nlast\n")
  assert_eq(tail.hunks[0].previous_start_line, 2)
  assert_eq(tail.hunks[0].previous_line_count, 0)
  let newline = diff_document_source("line", "line\n")
  assert_eq(newline.total_hunks, Some(1))
  assert_eq(newline.hunks[0].previous_text, "line")
  assert_eq(newline.hunks[0].current_text, "line\n")
  let crlf = diff_document_source("line\r\n", "line\n")
  assert_eq(crlf.total_hunks, Some(1))
  assert_eq(crlf.hunks[0].previous_text, "line\r\n")
}

///|
// Independent oracle: enumerate subsequences rather than dynamic programming.
fn diff_test_lcs_oracle(before : Array[String], after : Array[String]) -> Int {
  let mut combinations = 1
  for _ in before {
    combinations *= 2
  }
  let mut longest = 0
  for mask = 0; mask < combinations; mask = mask + 1 {
    let mut divisor = 1
    let mut cursor = 0
    let mut length = 0
    let mut valid = true
    for line in before {
      if mask / divisor % 2 == 1 {
        while cursor < after.length() && after[cursor] != line {
          cursor += 1
        }
        if cursor == after.length() {
          valid = false
          break
        }
        cursor += 1
        length += 1
      }
      divisor *= 2
    }
    if valid {
      longest = Int::max(longest, length)
    }
  }
  longest
}

///|
test "961 exhaustive duplicate-line pairs reconstruct exactly with minimal edits" {
  let sequences : Array[Array[String]] = [[]]
  let mut combinations = 1
  for size = 1; size <= 4; size = size + 1 {
    combinations *= 2
    for mask = 0; mask < combinations; mask = mask + 1 {
      let lines : Array[String] = []
      let mut divisor = 1
      for index = 0; index < size; index = index + 1 {
        lines.push(if mask / divisor % 2 == 0 { "a\n" } else { "b\n" })
        divisor *= 2
      }
      sequences.push(lines)
    }
  }
  assert_eq(sequences.length(), 31)
  for before in sequences {
    for after in sequences {
      let diff = diff_document_source(before.join(""), after.join(""))
      assert_true(diff.complete)
      assert_false(diff.display_truncated)
      let output = StringBuilder()
      let mut old_cursor = 0
      let mut new_cursor = 0
      let mut added = 0
      let mut removed = 0
      for hunk in diff.hunks {
        let old_start = hunk.previous_start_line - 1
        let new_start = hunk.current_start_line - 1
        assert_true(old_start >= old_cursor && new_start >= new_cursor)
        assert_eq(
          before[old_cursor:old_start].join(""),
          after[new_cursor:new_start].join(""),
        )
        assert_eq(
          hunk.previous_text,
          before[old_start:old_start + hunk.previous_line_count].join(""),
        )
        assert_eq(
          hunk.current_text,
          after[new_start:new_start + hunk.current_line_count].join(""),
        )
        output.write_string(before[old_cursor:old_start].join(""))
        output.write_string(hunk.current_text)
        old_cursor = old_start + hunk.previous_line_count
        new_cursor = new_start + hunk.current_line_count
        removed += hunk.previous_line_count
        added += hunk.current_line_count
      }
      output.write_string(before[old_cursor:].join(""))
      assert_eq(output.to_string(), after.join(""))
      assert_eq(diff.added_lines, Some(added))
      assert_eq(diff.removed_lines, Some(removed))
      assert_eq(
        added + removed,
        before.length() +
        after.length() -
        2 * diff_test_lcs_oracle(before, after),
      )
    }
  }
}

///|
test "duplicate-line ties deterministically prefer deletion" {
  let diff = diff_document_source("a\nb\na\n", "a\na\nb\n")
  assert_eq(diff.hunks.length(), 2)
  assert_eq(diff.hunks[0].previous_start_line, 2)
  assert_eq(diff.hunks[0].previous_text, "b\n")
  assert_eq(diff.hunks[0].current_line_count, 0)
  assert_eq(diff.hunks[1].current_start_line, 3)
}

///|
test "shared ten thousand lines are trimmed before table budgeting" {
  let common = Array::make(5000, "unchanged\n").join("")
  let diff = diff_document_source(
    common + "before\n" + common,
    common + "after\n" + common,
  )
  assert_true(diff.complete)
  assert_eq(diff.total_hunks, Some(1))
  assert_eq(diff.hunks[0].previous_start_line, 5001)
  assert_eq(diff.previous_line_count, Some(10001))
}

///|
test "cell budget includes table boundary rows and columns" {
  let before : Array[String] = []
  let after : Array[String] = []
  for i = 0; i < 511; i = i + 1 {
    before.push("before-\{i}\n")
    after.push("after-\{i}\n")
  }
  let boundary = diff_document_source(before.join(""), after.join(""))
  assert_true(boundary.complete)
  assert_eq(boundary.added_lines, Some(511))
  before.push("last-before\n")
  after.push("last-after\n")
  let exceeded = diff_document_source(before.join(""), after.join(""))
  assert_false(exceeded.complete)
  assert_eq(exceeded.reason, Some("cell_limit"))
  assert_eq(exceeded.added_lines, None)
  assert_eq(exceeded.total_hunks, None)
  assert_true(exceeded.hunks.is_empty())
}

///|
test "input and line limits fail explicitly without inventing edit counts" {
  let input = diff_document_source(
    String::from_array(Array::make(262145, 'x')),
    "",
  )
  assert_false(input.complete)
  assert_eq(input.reason, Some("input_limit"))
  assert_eq(input.previous_line_count, None)
  let lines = diff_document_source(Array::make(16385, "x\n").join(""), "")
  assert_false(lines.complete)
  assert_eq(lines.reason, Some("line_limit"))
  assert_eq(lines.previous_line_count, Some(16385))
  assert_eq(lines.removed_lines, None)
}

///|
test "display hunk limit retains complete edit totals" {
  let before : Array[String] = []
  let after : Array[String] = []
  for i = 0; i < 30; i = i + 1 {
    before.push("old-\{i}\nshared-\{i}\n")
    after.push("new-\{i}\nshared-\{i}\n")
  }
  let diff = diff_document_source(before.join(""), after.join(""))
  assert_true(diff.complete)
  assert_true(diff.display_truncated)
  assert_eq(diff.hunks.length(), 20)
  assert_eq(diff.total_hunks, Some(30))
  assert_eq(diff.added_lines, Some(30))
  assert_eq(diff.removed_lines, Some(30))
}

///|
test "Unicode excerpts are bounded separately from exact line counts" {
  let diff = diff_document_source(
    String::from_array(Array::make(700, '😀')),
    "replacement\n",
  )
  assert_true(diff.complete)
  assert_true(diff.display_truncated)
  assert_true(diff.hunks[0].text_truncated)
  assert_eq(diff.hunks[0].previous_text.to_array().length(), 514)
  assert_true(diff.hunks[0].previous_text.has_suffix("\n…"))
  assert_eq(diff.removed_lines, Some(1))
}
