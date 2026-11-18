# Pipeline observability

Run from the repository root using Python 3.9+. The parent records measurements;
specialists provide evidence. No additional agent or external service is required.
Artifacts remain in the ignored `.pipeline/` directory. Do not store prompts,
credentials, or raw session contents in events.

Initialize a unique directory before the planner (replace example identifiers and
the commit with actual values). Do not create the directory beforehand:

```sh
python3 scripts/evaluate_pipeline.py init .pipeline/ULENDO-8-run-001 --task-id ULENDO-8-feature --issue-id ULENDO-8 --task-type feature --base-commit ACTUAL_COMMIT
python3 scripts/evaluate_pipeline.py event .pipeline/ULENDO-8-run-001 stage --name planner --result started
python3 scripts/evaluate_pipeline.py event .pipeline/ULENDO-8-run-001 stage --name planner --result completed
python3 scripts/evaluate_pipeline.py event .pipeline/ULENDO-8-run-001 stage --name firebase_coder --result skipped --reason 'No backend scope'
python3 scripts/evaluate_pipeline.py event .pipeline/ULENDO-8-run-001 check --name 'flutter analyze' --result blocked --reason 'SDK unavailable'
python3 scripts/evaluate_pipeline.py event .pipeline/ULENDO-8-run-001 review --result approve
python3 scripts/evaluate_pipeline.py event .pipeline/ULENDO-8-run-001 finish --result completed --commit ACTUAL_FINAL_COMMIT --criteria-met
python3 scripts/evaluate_pipeline.py report
```

Use `--help` on any command for its arguments. Record start and terminal events for
each agent. Record check attempts once, including failures before a rerun; only
required checks belong in these counters. Mark unexecuted checks blocked or skipped,
with reasons. `completed` means the requested pipeline stages finished, even if
the reviewer requested changes; it does not mean the feature was accepted.
Use `failed` for failed orchestration and `blocked` when execution cannot continue.
Acceptance criteria may remain unknown by omitting `--criteria-met`; use
`--no-criteria-met` for observed unmet criteria.

Record a user correction with `event DIRECTORY intervention --reason '...'`.
Record explicit acceptance with `event DIRECTORY acceptance --accepted`, or explicit
rejection with `--no-accepted`. Until observed, acceptance is null. This event may
arrive after the pipeline finishes. Keep a stable task ID across revision runs;
different task types, such as architecture reviews and features, need distinct IDs.

The scorecard deduplicates tasks across retries and uses the earliest observed
review for first-pass approval. Checks are execution counts. Blocked and skipped
checks are reported separately and never count as passes. Time is elapsed wall
time per finished run, including waits. Cost per accepted task includes costs of
all attempted runs; it stays unknown if any run lacks cost data. The report covers
only instrumented runs, not every task ever attempted in the repository.

`event DIRECTORY usage --input-tokens N --output-tokens N --estimated-cost-usd N
--source 'metadata reference and pricing basis'` replaces the run's total usage
snapshot. Supply only observed fields; omitted fields remain null. Do not sum
cumulative token updates. Include all associated agent sessions exactly once;
never infer usage or cost from elapsed time. Costs require actual usage and a
documented pricing basis. No pricing is embedded in this tool.

Historical session import is deferred: session association and usage formats need
validation against actual logs first. This tool does not scan personal Codex logs
or claim to reconstruct old runs. Start with five fully instrumented runs before
building a dashboard or comparing against a single-agent baseline.

`metrics.json` uses schema version 1 and contains identity, task type, commits,
status, UTC timestamps, review counters, verification counters, interventions,
nullable usage, and separate acceptance observations. `events.jsonl` contains a
timestamp, event type, and event-specific arguments for each recorded action.
These are local, single-writer files; avoid concurrent writes. Appending an event
and updating its summary are not transactional: if interrupted, compare the event
log with the summary before resuming. Events are recorded when the command runs,
so do not backfill earlier actions as if their times were measured.

Verification:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -v
```
