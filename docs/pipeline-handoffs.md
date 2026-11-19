# Pipeline handoff formats

Handoffs report results for the next stage. Use the sections below; write `None`
when a section has no entries. Use absolute paths for evidence and source references.
Keep full stdout/stderr in separate files inside the repository, such as
`.pipeline/<run-id>/logs/<role>/`. Do not copy logs or requirements into reports.
Capture evidence at execution time; never reconstruct missing output as if recorded.
If an evidence file is unavailable, say so and retain the observed result and gap.

Target 500 words excluding tables. This is a brevity target, not a cap on findings.
Read the spec and relevant source as required; a short handoff does not replace them.

For every executed check, record the tested commit and any relevant uncommitted
paths/state (use a patch or content digest when needed to distinguish versions),
working directory, and relevant runtime/environment alongside the command and
result. Never record secrets. This identifies which inputs the evidence covers;
HEAD alone is insufficient when relevant files were modified. For reruns, include
the reason and the earlier attempt ID. Inherited results retain their original
attempt IDs and evidence paths and are not new telemetry executions. Reuse them
only under AGENTS.md's verification rules; required repeatability runs still execute.

## Focused revision spec

Use this for the new run's `spec.md` after the user inspects a completed pipeline
and requests changes. This is a correction plan, not a replacement feature spec.
Keep it concise; preserve enough detail to implement and verify every correction.

```markdown
# Revision spec
Run: <new run-id> | Task: <stable task-id> | Issue: <issue-id>
Branch: <existing feature branch> | Original base: <unchanged hash>
Baseline spec: <absolute original spec path>
Applicable earlier revisions: <exact paths, or None>
Previous review: <absolute path>
Implementation at planning: <HEAD and relevant uncommitted state>

## Required corrections
- <correction ID> — <user request/review finding; relevant paths and intended behavior>

## Requirements changed and behavior preserved
- <criterion ID explicitly replaced> — <updated requirement and reason; or None>
- <specific behavior/contracts at risk that must remain unchanged>
- All other baseline and applicable revision requirements remain in force.

## Ownership and contracts
- <required specialist> — <owned paths, interfaces and cross-stack dependencies>
- <skipped specialist> — <reason>

## Acceptance and verification
- <correction ID> — <observable acceptance, focused regression checks and evidence>
- <applicable existing checks; evidence reuse/rerun decisions follow AGENTS.md>

## Blockers and unresolved decisions
- <issue, impact and next action; or None>
```

For multiple revisions, retain references to earlier corrections still in force.
The parent includes all applicable spec paths in every stage input. Avoid copying
their content into the new plan. New user requests govern intentional changes;
report ambiguities instead of assuming requirements have been removed.
Review still covers the full feature diff against the original base, including
preserved feature behavior and the latest corrections.

## Specialist and combined implementation reports

Use for `changes-firebase.md`, `changes-flutter.md`, and parent-owned `changes.md`.

```markdown
# Implementation handoff
Run: <run-id> | Task: <task-id> | Issue: <issue-id>
Branch: <branch> | Original base: <hash>
Scope/status: <implemented scope and complete/partial/blocked>

## Changed paths
- <path> — <behavior changed; acceptance-criterion ID where applicable>

## Contracts and deviations
- <API/data contract changes, compatibility implications, spec deviations; or None>

## Commits
- <full hash> — <subject>
- Uncommitted: <owned paths and reason, or None>

## Checks
| Attempt | Command / relevant environment | Result | Evidence |
| --- | --- | --- | --- |
| <role>-1 | <exact command; cwd and non-secret overrides> | <passed/failed/blocked/skipped; exit code and counts if available> | <log path; concise reason for non-pass> |

## Blockers and remaining gaps
- <unmet criterion, impact, next action and evidence; or None>
```

The combined report preserves both specialists' changed paths, contracts, commit
hashes/subjects, check results, and blockers. Record skipped specialists with reasons.
Link to the source handoffs. Retain attempt IDs when combining evidence so one
execution is not counted twice. Do not rerun a check merely to populate a table.

## Tester report

Use for `tests.md`, with the same run/task/issue, branch, and original-base header.

```markdown
## Test changes
- <test path> — <behavior or edge case covered; criterion ID>

## Test commits
- <full hash> — <subject>
- Uncommitted: <test paths and reason, or None>

## Check results
| Attempt / source | Command / relevant environment | Result | Evidence |
| --- | --- | --- | --- |
| tester-1 / new execution | <exact command and cwd> | <status, exit code, counts> | <log path> |
| <coder attempt ID> / inherited | <command from changes.md> | <reported status; not rerun> | <original evidence path> |

## Defects, blockers and acceptance gaps
- <finding or unmet criterion, impact, source reference and next action; or None>
```

Distinguish new executions from inherited evidence. List relevant unexecuted checks
as blocked or skipped with reasons, never as passed. Separate diagnostic results
from acceptance under the required runtime/environment. Preserve exact commands,
results and evidence needed by the parent to record each actual attempt.

## Review report

The reviewer returns this report; the parent saves it as `review.md`.
Use the same run/task/issue, branch, and original-base header.

```markdown
Verdict: APPROVE / REQUEST CHANGES

## Findings
- [P<priority>] <source path:line> — <defect, trigger, impact and required correction>

## Verification assessment
- <acceptance gaps, blocked/unexecuted checks, and evidence references; or None>
- <new reviewer checks with command, result and evidence; distinguish inherited evidence>

## Scope and remaining risks
- <material scope, architecture, telemetry or uncommitted-change concerns; or None>
```

Inspect the full feature diff against the original base and required stage inputs.
Report every material actionable finding even if the report exceeds the target.
Approval does not establish human acceptance or authorize merging.
