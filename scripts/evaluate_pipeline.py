#!/usr/bin/env python3
"""Deterministic local pipeline telemetry. Python standard library only."""
import argparse
import json
import math
from datetime import datetime, timezone
from pathlib import Path


def timestamp():
    return datetime.now(timezone.utc).isoformat()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def initialize(directory, task_id, task_type, base_commit, issue_id=None):
    directory.mkdir(parents=True, exist_ok=False)
    metrics = dict(schema_version=1, run_id=directory.name, task_id=task_id,
                   task_type=task_type, issue_id=issue_id, base_commit=base_commit,
                   final_commit=None, status="in_progress", started_at=timestamp(),
                   ended_at=None, review=dict(rounds=0, first_pass_approved=None,
                                             final_verdict=None),
                   verification=dict(passed=0, failed=0, blocked=0, skipped=0),
                   human_interventions=0,
                   usage=dict(input_tokens=None, output_tokens=None,
                              estimated_cost_usd=None),
                   outcome=dict(acceptance_criteria_met=None, human_accepted=None))
    write(directory / "metrics.json", metrics)
    (directory / "events.jsonl").write_text(json.dumps(dict(
        timestamp=metrics["started_at"], event="run_started")) + "\n")


def record(directory, kind, data):
    path = directory / "metrics.json"
    metrics = json.loads(path.read_text())
    if kind == "check":
        metrics["verification"][data["result"]] += 1
    elif kind == "review":
        review = metrics["review"]
        review["rounds"] += 1
        if review["rounds"] == 1:
            review["first_pass_approved"] = data["result"] == "approve"
        review["final_verdict"] = data["result"]
    elif kind == "intervention":
        metrics["human_interventions"] += 1
    elif kind == "acceptance":
        metrics["outcome"]["human_accepted"] = data["accepted"]
    elif kind == "finish":
        if metrics["ended_at"]:
            raise ValueError("Run already finished")
        metrics.update(status=data["result"], ended_at=timestamp(),
                       final_commit=data["commit"])
        metrics["outcome"]["acceptance_criteria_met"] = data["criteria_met"]
    elif kind == "usage":
        for key in metrics["usage"]:
            value = data.get(key)
            if value is not None and (not isinstance(value, (int, float)) or
                                      value < 0 or not math.isfinite(value)):
                raise ValueError("Usage must be finite and nonnegative")
        metrics["usage"] = {key: data.get(key) for key in metrics["usage"]}
        metrics["usage_source"] = data["source"]
    elif kind != "stage":
        raise ValueError("Unknown event")
    if kind in ("stage", "check") and data["result"] in ("failed", "blocked", "skipped") and not data.get("reason"):
        raise ValueError("Failure, blocked, or skipped outcomes require a reason")
    with (directory / "events.jsonl").open("a") as stream:
        stream.write(json.dumps(dict(timestamp=timestamp(), event=kind, **data)) + "\n")
    write(path, metrics)


def report(root):
    runs = [json.loads(p.read_text()) for p in sorted(root.glob("*/metrics.json"))]
    tasks = {r["task_id"] for r in runs}
    accepted = {r["task_id"] for r in runs if r["outcome"]["human_accepted"] is True}
    # First review across retries, not the first review of every fresh run.
    first_reviews = {}
    for run in sorted(runs, key=lambda r: r["started_at"]):
        if run["review"]["rounds"]:
            first_reviews.setdefault(run["task_id"], run["review"]["first_pass_approved"])
    counts = {k: sum(r["verification"][k] for r in runs)
              for k in ("passed", "failed", "blocked", "skipped")}
    def ratio(a, b):
        return f"{a}/{b} ({a / b:.1%})" if b else "unknown"
    durations = [(datetime.fromisoformat(r["ended_at"]) - datetime.fromisoformat(r["started_at"])).total_seconds()
                 for r in runs if r["ended_at"]]
    costs = [r["usage"]["estimated_cost_usd"] for r in runs]
    measured_cost = bool(runs) and all(c is not None for c in costs)
    tokens = {key: (sum(r["usage"][key] for r in runs)
                    if runs and all(r["usage"][key] is not None for r in runs) else "unknown")
              for key in ("input_tokens", "output_tokens")}
    return "\n".join([
        "# Pipeline scorecard", "",
        f"Runs: {len(runs)}; distinct tasks: {len(tasks)}",
        f"Human-accepted tasks: {ratio(len(accepted), len(tasks))}",
        f"Completed pipeline runs: {sum(r['status'] == 'completed' for r in runs)}/{len(runs)}",
        f"First-pass task review approvals: {ratio(sum(v is True for v in first_reviews.values()), len(first_reviews))}",
        f"Required checks passed / executed: {ratio(counts['passed'], counts['passed'] + counts['failed'])}",
        f"Blocked checks: {counts['blocked']}; skipped checks: {counts['skipped']}",
        f"Human interventions: {sum(r['human_interventions'] for r in runs)}",
        f"Mean finished-run seconds: {sum(durations) / len(durations) if durations else 'unknown'}",
        f"Input tokens: {tokens['input_tokens']}; output tokens: {tokens['output_tokens']}",
        f"Measured cost / accepted task (USD): {sum(costs) / len(accepted) if measured_cost and accepted else 'unknown'}",
        f"Runs with measured cost: {sum(c is not None for c in costs)}/{len(runs)}",
        "", "Blocked and skipped checks never count as passes. Review approval is not human acceptance.",
    ]) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    init = commands.add_parser("init")
    init.add_argument("directory", type=Path)
    init.add_argument("--task-id", required=True)
    init.add_argument("--task-type", choices=["feature", "review", "workflow", "evaluation"], required=True)
    init.add_argument("--base-commit", required=True)
    init.add_argument("--issue-id")
    event = commands.add_parser("event")
    event.add_argument("directory", type=Path)
    kinds = event.add_subparsers(dest="kind", required=True)
    for name, choices in (("stage", ["started", "completed", "failed", "blocked", "skipped"]),
                          ("check", ["passed", "failed", "blocked", "skipped"]),
                          ("review", ["approve", "request_changes"]),
                          ("finish", ["completed", "failed", "blocked"])):
        item = kinds.add_parser(name)
        item.add_argument("--result", choices=choices, required=True)
        if name in ("stage", "check"):
            item.add_argument("--name", required=True)
            item.add_argument("--reason")
        if name == "finish":
            item.add_argument("--commit", required=True)
            item.add_argument("--criteria-met", action=argparse.BooleanOptionalAction, default=None)
    item = kinds.add_parser("intervention")
    item.add_argument("--reason", required=True)
    item = kinds.add_parser("acceptance")
    item.add_argument("--accepted", action=argparse.BooleanOptionalAction, required=True)
    item = kinds.add_parser("usage")
    item.add_argument("--input-tokens", type=int)
    item.add_argument("--output-tokens", type=int)
    item.add_argument("--estimated-cost-usd", type=float)
    item.add_argument("--source", required=True)
    item = commands.add_parser("report")
    item.add_argument("root", type=Path, nargs="?", default=Path(".pipeline"))
    args = vars(parser.parse_args())
    command = args.pop("command")
    if command == "report":
        print(report(args["root"]), end="")
    else:
        directory = args.pop("directory")
        if command == "init":
            initialize(directory, **args)
        else:
            record(directory, args.pop("kind"), args)


if __name__ == "__main__":
    main()
