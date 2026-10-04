"""Verify the documented consumer handles version and extension boundaries."""
import importlib.util
import json
from pathlib import Path
import unittest

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("report_reader", REPO / "examples/integration/read_report.py")
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


class ReportContractTests(unittest.TestCase):
    def setUp(self):
        self.report = json.loads((REPO / "examples/integration/report.json").read_text())

    def test_real_report_can_be_summarized_with_future_fields(self):
        self.report["future_metadata"] = {"unknown": True}
        summary = reader.summarize(self.report)
        self.assertEqual(summary["categories"], {"verified": 3})
        self.assertEqual(summary["failed"], 0)

    def test_unknown_categories_remain_visible_for_review(self):
        self.report["items"].append({"category": "future_category"})
        self.assertEqual(reader.summarize(self.report)["unknown_items_need_review"], 1)

    def test_unknown_status_requires_review_even_with_a_known_category(self):
        self.report["items"].append({"category": "verified", "status": "future_status"})
        self.assertEqual(reader.summarize(self.report)["unknown_items_need_review"], 1)

    def test_unsupported_or_legacy_schemas_are_rejected(self):
        for version in (None, 2, True):
            with self.subTest(version=version), self.assertRaises(ValueError):
                reader.summarize({**self.report, "schema_version": version})

    def test_boolean_and_negative_counts_are_not_accepted(self):
        for count in (True, -1):
            with self.subTest(count=count), self.assertRaises(ValueError):
                reader.summarize({**self.report, "failed_count": count})


if __name__ == "__main__":
    unittest.main()
