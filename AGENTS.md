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

To run all four project agents, ask Codex:

> Run the feature pipeline for [feature]. Delegate sequentially to planner, coder,
> tester, and reviewer.

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

The planner records the branch name in `spec.md` using
`ULENDO-<issue-number>/<short-task-description>`, for example
`ULENDO-8/rider-experience`. Use the supplied issue number and a lowercase,
hyphen-separated task description. If the issue number is missing, ask the
user before creating the branch. The coder uses that branch in the current
checkout and the tester commits to it too. Include the issue ID in each
Conventional Commit subject, for example
`feat(rider): ULENDO-8 add pickup confirmation` or
`test(rider): ULENDO-8 cover pickup confirmation`.

The coder commits implementation in small, cohesive steps as work progresses.
When the tester adds or changes test code, commit those changes in separate,
focused steps. Follow Conventional Commits and describe the specific behavior
or coverage each step adds. Use a commit body when the reason for the change
needs context. Stage only files or hunks you own and preserve unrelated changes.
Record commit hashes and subjects in `changes.md` and `tests.md`, respectively.
If committing is blocked, report it in the handoff along with the affected changes.

Stop at the verdict and leave merging to the user.

If the user requests changes after review, keep the current checkout and start a
fresh run directory. Give the planner the user's feedback, the previous spec and
review, and the current implementation. Ask for a revised spec that records the
requested changes, updated acceptance criteria, and behavior to preserve. Pass
the revised spec to the coder, then run the tester and reviewer again. The
reviewer checks the full feature diff against the original base commit. Report
the new verdict and wait for the user's decision.
