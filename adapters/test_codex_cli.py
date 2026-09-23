from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from codex_cli import ExportError, export


FIXTURE = Path(__file__).resolve().parents[1] / "fixtures" / "codex-cli-events.jsonl"


class CodexCliExportTest(unittest.TestCase):
    def setUp(self) -> None:
        self.events = [json.loads(line) for line in FIXTURE.read_text(encoding="utf-8").splitlines()]

    def test_observed_call_result_and_citation(self) -> None:
        trace = export(self.events)
        self.assertEqual([event["type"] for event in trace], ["tool_call", "tool_result", "answer"])
        self.assertEqual(trace[1]["sources"][0]["id"], "source-1")
        self.assertEqual(trace[2]["claims"][0]["source_ids"], ["source-1"])
        self.assertNotIn("answer=42", json.dumps(trace))

    def test_unknown_answer_citation_stays_unknown(self) -> None:
        events = copy.deepcopy(self.events)
        events[-2]["item"]["text"] = "42 [source-99]"
        trace = export(events)
        self.assertEqual(trace[-1]["claims"][0]["source_ids"], ["source-99"])

    def test_failed_command_cannot_supply_source(self) -> None:
        events = copy.deepcopy(self.events)
        events[-3]["item"]["exit_code"] = 1
        trace = export(events)
        self.assertFalse(trace[1]["ok"])
        self.assertEqual(trace[1]["sources"], [])

    def test_incomplete_turn_is_rejected(self) -> None:
        with self.assertRaisesRegex(ExportError, "turn.completed"):
            export(self.events[:-1])


if __name__ == "__main__":
    unittest.main()
