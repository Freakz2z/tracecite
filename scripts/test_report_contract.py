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

    def test_quote_counts_extend_v1_without_changing_old_web_counts(self):
        self.assertEqual(reader.summarize(self.report)["skipped_quotes"], 0)
        self.report.update(skipped_quotes=2, skipped_count=1, unassociated_quotes="skip")
        summary = reader.summarize(self.report)
        self.assertEqual((summary["skipped_quotes"], summary["skipped_web"]), (2, 1))
        for value in (True, -1, "2", None):
            with self.subTest(value=value), self.assertRaises(ValueError):
                reader.summarize({**self.report, "skipped_quotes": value})

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

    def test_non_object_reports_have_a_clear_validation_error(self):
        for value in (None, [], "text", 0, True):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "JSON object"):
                reader.summarize(value)

    def test_malformed_items_stay_visible_without_crashing_the_reader(self):
        malformed = [None, [], "text", {"category": "verified", "status": []},
                     {"category": "verified", "status": {}}, {"category": [], "status": "ok"}]
        self.report["items"].extend(malformed)
        summary = reader.summarize(self.report)
        self.assertEqual(summary["unknown_items_need_review"], len(malformed))
        self.assertEqual(summary["categories"], {"verified": 3})


if __name__ == "__main__":
    unittest.main()
