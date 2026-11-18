import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "telemetry", Path(__file__).parents[1] / "evaluate_pipeline.py")
telemetry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(telemetry)


class TelemetryTest(unittest.TestCase):
    def setUp(self):
        # Keep all test artifacts within the project, as required by AGENTS.md.
        self.temp = tempfile.TemporaryDirectory(dir=Path(__file__).parents[2])
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.run = self.root / "run-1"
        telemetry.initialize(self.run, "task-1", "workflow", "base")

    def metrics(self):
        return json.loads((self.run / "metrics.json").read_text())

    def test_unknowns_and_no_overwrite(self):
        self.assertIsNone(self.metrics()["usage"]["input_tokens"])
        self.assertIsNone(self.metrics()["outcome"]["human_accepted"])
        with self.assertRaises(FileExistsError):
            telemetry.initialize(self.run, "task-1", "workflow", "base")

    def test_checks_reviews_and_acceptance_are_separate(self):
        for result in ("passed", "failed", "blocked", "skipped"):
            telemetry.record(self.run, "check", dict(name="check", result=result, reason="evidence"))
        telemetry.record(self.run, "review", dict(result="request_changes"))
        telemetry.record(self.run, "review", dict(result="approve"))
        self.assertFalse(self.metrics()["review"]["first_pass_approved"])
        self.assertIsNone(self.metrics()["outcome"]["human_accepted"])
        report = telemetry.report(self.root)
        self.assertIn("1/2 (50.0%)", report)
        self.assertIn("Blocked checks: 1; skipped checks: 1", report)

    def test_retries_do_not_inflate_tasks_or_first_pass(self):
        telemetry.record(self.run, "review", dict(result="request_changes"))
        second = self.root / "run-2"
        telemetry.initialize(second, "task-1", "workflow", "base")
        telemetry.record(second, "review", dict(result="approve"))
        telemetry.record(second, "acceptance", dict(accepted=True))
        report = telemetry.report(self.root)
        self.assertIn("distinct tasks: 1", report)
        self.assertIn("First-pass task review approvals: 0/1", report)
        self.assertIn("Human-accepted tasks: 1/1", report)

    def test_usage_snapshot_replaces_cumulative_totals(self):
        for total in (10, 20):
            telemetry.record(self.run, "usage", dict(input_tokens=total, source="fixture"))
        self.assertEqual(self.metrics()["usage"]["input_tokens"], 20)
        self.assertIn("Measured cost / accepted task (USD): unknown", telemetry.report(self.root))
        with self.assertRaises(ValueError):
            telemetry.record(self.run, "usage", dict(input_tokens=-1, source="fixture"))

    def test_finish_and_event_timestamps(self):
        telemetry.record(self.run, "finish", dict(result="blocked", commit="base", criteria_met=None))
        self.assertEqual(self.metrics()["status"], "blocked")
        self.assertIsNotNone(self.metrics()["ended_at"])
        with self.assertRaises(ValueError):
            telemetry.record(self.run, "finish", dict(result="completed", commit="base", criteria_met=True))
        events = [json.loads(line) for line in (self.run / "events.jsonl").read_text().splitlines()]
        self.assertEqual(len(events), 2)
        self.assertTrue(all(event["timestamp"].endswith("+00:00") for event in events))

    def test_failure_requires_reason_without_writing(self):
        with self.assertRaises(ValueError):
            telemetry.record(self.run, "stage", dict(name="tester", result="blocked"))
        self.assertEqual(len((self.run / "events.jsonl").read_text().splitlines()), 1)


if __name__ == "__main__":
    unittest.main()
