# Repository Guidelines

## Project Structure

- `apps/rider_app` and `apps/driver_app` are Flutter apps. Feature code lives in `lib/`, widget tests in `test/`, and platform projects in `android/` and `ios/`. App icons and launch images live in the platform resource directories.
- `packages/ulendo_core` holds shared app logic, `packages/ulendo_ui` holds shared UI and themes, and `packages/ulendo_models` holds shared data models.
- `functions/src/` contains the TypeScript Firebase backend. Register function exports in `functions/src/index.ts`. Firebase rules, indexes, and emulator settings live at the repository root.

## Build and Development

- Run `flutter pub get` at the root to resolve workspace dependencies. Run `dart run melos run run:rider` or `dart run melos run run:driver` with a simulator, emulator, or device available.
- From the target app directory, run `flutter build apk` for Android or `flutter build ios` for iOS on macOS with Xcode.
- In `functions/`, use Node.js 20 and run `npm ci`, `npm run lint`, and `npm run build` to install, lint, and compile. With the Firebase CLI available, `npm run serve` builds and starts the Functions emulator.

## Coding Style

Use two spaces for indentation. For Dart, use `snake_case.dart` filenames, `UpperCamelCase` types, and `lowerCamelCase` members. Run `dart format` on changed Dart files and `flutter analyze` in affected modules. Keep app-specific BLoCs, repositories, and widgets with their features. Follow the Functions ESLint configuration, including double quotes and spaces inside object braces.

## Testing

Name Dart tests `*_test.dart` and place them under the owning module's `test/` directory. Run `flutter test` from the affected Flutter app or package and `dart test` from `packages/ulendo_models`. Cover changed behavior and document emulator checks for backend changes. The repository has no configured coverage threshold or Functions test script.

## Commits and Pull Requests

Follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/). Use `<type>(<optional scope>): <description>`, for example `feat(rider): add trip management` or `fix(driver): restore ride acceptance`. Mark breaking changes with `!` before the colon or a `BREAKING CHANGE:` footer.

In pull requests, link the issue, summarize the affected apps or services, list verification steps, and attach screenshots for visible UI changes.

## Feature Pipeline

### Parent preflight

Before dispatching the planner, the parent performs these lightweight checks;
do not spawn an agent for preflight:

- Confirm the supplied ULENDO issue number from the request or established session
  context. Do not invent or increment it. If missing or conflicting, ask the user
  before dispatching the planner.
- Confirm the intended feature branch using
  `ULENDO-<issue-number>/<short-task-description>`. Inspect
  `git branch --show-current`, `git status --short`, and `git rev-parse HEAD`
  to record the current branch, checkout changes, and base commit. Reuse an
  already-confirmed branch. Preserve existing changes; a dirty checkout alone is
  not a blocker. Resolve an ambiguous target branch or conflicting changes before
  dispatch, and report any branch-setup failure before starting the planner.
- For a continuation or retry, read the latest relevant attempt's handoff and
  blocker evidence, if available. Carry forward known unresolved blockers rather
  than rediscovering them. Report what is still blocked and which stage it affects;
  resolve blockers that prevent useful planning before dispatch. Pass downstream
  blockers to the planner and the responsible specialist. If no previous attempt
  exists, record that there are no known prior blockers.

Record a concise preflight result in the run telemetry initialized below before
planner dispatch. Keep this check limited to issue, branch/checkout, and known
blockers. Dependency and runtime verification belongs to the coding and test
agents for their assigned scope; do not perform a broad dependency scan here.

### Agent context through the run folder

Before each stage, the parent writes `.pipeline/<run-id>/input-<role>.md`,
where role is `planner`, `firebase_coder`, `flutter_coder`, `tester`, or `reviewer`.
Create only the inputs needed for stages that will run. Each input contains:

- The task objective, relevant user requirements and decisions, and stage assignment.
- Repository root, run ID, stable task ID, issue ID, confirmed branch, run directory,
  and original base commit (preserved across revisions).
- Assigned path ownership, relevant source entry points, and required API/data
  contracts, directly or by reference to the spec.
- Known blockers and checkout changes to preserve, including their evidence paths.
- Exact paths to required reading and the expected handoff filename. The reviewer
  returns its verdict to the parent, who writes `review.md`.

Use concise summaries and file references rather than conversation transcripts or
copied logs. Preserve all applicable user constraints in these files; agents must
not need the parent chat to understand their assignment. Use absolute paths for
input and referenced files. Before dispatch, ensure required input files exist
and reflect the latest completed handoffs and user decisions.

Spawn each stage with `fork_turns="none"` and a short message identifying its role,
repository root, and absolute input-file path. Tell it to read that file and
applicable AGENTS.md instructions first. Do not inherit the parent conversation.
If context cannot be supplied through files, report the limitation rather than
silently dispatching with incomplete requirements.

Agents read their input, its required references, and source relevant to their
scope; they do not scan the entire run folder or unrelated historical runs.
Required stage reading remains:

- Planner: feature requirements; architecture; prior spec/review and user feedback
  for revisions, when applicable.
- Firebase coder: architecture and `spec.md`.
- Flutter coder: architecture, `spec.md`, and `changes-firebase.md` when Firebase ran.
- Tester: `spec.md` and combined `changes.md`.
- Reviewer: architecture, `spec.md`, `changes.md`, and `tests.md`; inspect the full
  feature diff against the original base commit.

When new user decisions affect a running stage, the parent updates its input file
and sends a short message pointing to the update. Agents report missing or
conflicting context to the parent instead of guessing. Return a concise stage
summary and handoff path; keep detailed evidence in referenced project files.

### Evaluation and observability

The parent must follow [the telemetry guide](docs/pipeline-observability.md) for
every new pipeline run. Before dispatching the planner, initialize the fresh run
directory with `scripts/evaluate_pipeline.py init`; this creates `metrics.json`
and `events.jsonl`. Pass the run ID, stable task ID, directory, and base commit
to every agent. Reuse the task ID on revision runs, keeping each run ID unique.
Record stage start immediately before dispatch and its terminal result after
the handoff. Record skipped specialists and blocked stages with reasons.
The parent is the sole telemetry writer; agents supply evidence in handoffs.
Record each required check execution and each review verdict, corrections or
rescue actions by the user, and the final pipeline result. Ordinary requirements
and approvals are not interventions. Pipeline completion, acceptance criteria,
review approval, and explicit human acceptance are separate observations.
Never infer human acceptance from review approval or merging readiness.
Use the tool's UTC timestamps. Never invent historical timestamps, usage, or cost.
Unavailable measurements remain null. Finish telemetry even when a run is blocked.
Include the telemetry paths and scorecard command in the final pipeline report.

Treat requests to run, test, or smoke-test the Ulendo agent workflow as
requests to delegate to the project agents. Spawn `planner`, the required coding
specialist(s), `tester`, and `reviewer` in order. Use `firebase_coder` for Firebase
JavaScript/TypeScript backend work and `flutter_coder` for Flutter/Dart frontend
work. The planner selects one or both and assigns explicit path ownership and
shared API/data contracts. When both are needed, run `firebase_coder` followed by
`flutter_coder` sequentially in the same checkout. Skip and report any specialist
whose scope is not needed. If a required named agent is unavailable, report
the blocker and stop before doing that stage in the main chat.

To run the feature pipeline, ask Codex:

> Run the feature pipeline for [feature]. Delegate sequentially to planner, the
> required Firebase and Flutter coding specialists, tester, and reviewer.

Run all stages from this repository root. Keep code, tests, and handoffs inside
the project folder. Use the current checkout and a fresh `.pipeline/<run-id>/`
directory. Do not create a separate worktree or request access outside the project
folder. If a check needs to write outside the project, report it as blocked. The
parent passes the same directory and base commit to every agent and waits for each
handoff before starting the next. Read `spec.md` before implementation,
`changes.md` before testing, and `tests.md` before review. The parent saves the
reviewer's verdict to `review.md` and reports any blockers and verification gaps.
The planner and reviewer read [architecture.md](architecture.md) before their
stages. Check Flutter layer boundaries and flag code that both apps could
reuse from a shared package under `packages/`.

Each coding specialist writes its own handoff: `changes-firebase.md` or
`changes-flutter.md`. Pass the backend handoff to the Flutter specialist when both
run. Before testing, the parent combines the specialist handoffs into `changes.md`,
preserving changed paths, contracts, commit hashes, check results, and blockers,
and records which specialists were skipped. Tester and reviewer read this combined
handoff. Specialists preserve each other's edits and report changes needed outside
their assigned ownership to the parent.

The planner records the branch name in `spec.md` using
`ULENDO-<issue-number>/<short-task-description>`, for example
`ULENDO-8/rider-experience`. Use the supplied issue number and a lowercase,
hyphen-separated task description. If the issue number is missing, ask the
user before creating the branch. Both coding specialists use that branch in the current
checkout and the tester commits to it too. Include the issue ID in each
Conventional Commit subject, for example
`feat(rider): ULENDO-8 add pickup confirmation` or
`test(rider): ULENDO-8 cover pickup confirmation`.

Each coding specialist commits implementation in small, cohesive steps as work progresses.
When the tester adds or changes test code, commit those changes in separate,
focused steps. Follow Conventional Commits and describe the specific behavior
or coverage each step adds. Use a commit body when the reason for the change
needs context. Stage only files or hunks you own and preserve unrelated changes.
Record implementation commit hashes and subjects in each specialist handoff and
the combined `changes.md`; record test commits in `tests.md`.
If committing is blocked, report it in the handoff along with the affected changes.

Report each agent that ran, the handoff paths, the feature branch, specialist and
tester commit hashes when applicable, and the review verdict. Identify stages
that were blocked or skipped. Stop at the verdict and leave merging to the user.

If the user requests changes after review, keep the current checkout and start a
fresh run directory. Give the planner the user's feedback, the previous spec and
review, and the current implementation. Ask for a revised spec that records the
requested changes, updated acceptance criteria, and behavior to preserve. Pass
the revised spec to the required coding specialists, combine their handoffs, then
run the tester and reviewer again. The
reviewer checks the full feature diff against the original base commit. Report
the new verdict and wait for the user's decision.
