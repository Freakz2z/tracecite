from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path
from typing import Any

from codex_cli import ExportError, export


FIXTURE = Path(__file__).resolve().parents[1] / "fixtures" / "codex-cli-events.jsonl"


class CodexCliExportTest(unittest.TestCase):
    def setUp(self) -> None:
        self.events = [json.loads(line) for line in FIXTURE.read_text(encoding="utf-8").splitlines()]

    def test_observed_call_result_and_citation(self) -> None:
        trace = export(self.events)
        self.assertEqual([event["type"] for event in trace], ["tool_call", "tool_result", "answer"])
        self.assertEqual(trace[1]["sources"][0]["id"], "source-1")
        self.assertEqual(trace[2]["claims"][0]["citations"], [{"source_id": "source-1", "quote": "42"}])
        self.assertEqual(trace[1]["sources"][0]["content"], "answer=42\nsource=local-fixture\n")
        self.assertNotIn("cat facts.txt", json.dumps(trace))

    def test_unknown_answer_citation_stays_unknown(self) -> None:
        events = copy.deepcopy(self.events)
        events[-2]["item"]["text"] = "42 [source-99]"
        trace = export(events)
        self.assertEqual(trace[-1]["claims"][0]["citations"], [{"source_id": "source-99", "quote": "42"}])

    def test_failed_command_cannot_supply_source(self) -> None:
        events = copy.deepcopy(self.events)
        events[-3]["item"]["exit_code"] = 1
        trace = export(events)
        self.assertFalse(trace[1]["ok"])
        self.assertEqual(trace[1]["sources"], [])

    def test_incomplete_turn_is_rejected(self) -> None:
        with self.assertRaisesRegex(ExportError, "turn.completed"):
            export(self.events[:-1])

    def test_bind_observed_output_to_file_for_independent_check(self) -> None:
        trace = export(self.events, {"source-1": "fixtures/facts.txt"})
        self.assertEqual(trace[1]["sources"][0]["uri"], "file:fixtures/facts.txt")
        with self.assertRaisesRegex(ExportError, "absent"):
            export(self.events, {"source-2": "fixtures/facts.txt"})

    def test_two_sanitized_real_runs_preserve_a_source_change(self) -> None:
        fixtures = Path(__file__).resolve().parents[1] / "fixtures"

        def read_events(name: str) -> list[dict[str, Any]]:
            return [
                json.loads(line)
                for line in (fixtures / name).read_text(encoding="utf-8").splitlines()
                if line.strip()
            ]

        binding = {"source-1": "fixtures/codex-live-run-source.txt"}
        before = export(read_events("codex-two-run-before-events.jsonl"), binding)
        after = export(read_events("codex-two-run-after-events.jsonl"), binding)

        self.assertEqual(before[1]["sources"][0]["uri"], after[1]["sources"][0]["uri"])
        self.assertEqual(before[1]["sources"][0]["content"], "The archive release date is 2026-10-01.\nThe maintainer is the Documentation Group.\n")
        self.assertEqual(after[1]["sources"][0]["content"], "The archive release date is 2026-10-04.\nThe maintainer is the Documentation Group.\n")
        self.assertEqual(before[2]["claims"][0]["citations"][0]["quote"], "The archive release date is 2026-10-01.")
        self.assertEqual(after[2]["claims"][0]["citations"][0]["quote"], "The archive release date is 2026-10-04.")


if __name__ == "__main__":
    unittest.main()
