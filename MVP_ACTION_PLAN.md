# Ulendo MVP action plan

Planning baseline: `dc0dd83662244ed543eeb5173451c154cdc8cf16`, reviewed 2026-11-18.
Status: proposed backlog only. No implementation, deployment, branch, or commits authorized by this plan.

## Target outcome

A controlled pilot in which a rider requests a trip, an eligible driver receives and accepts an offer, both apps observe arrival/start/completion, and each participant can recover after restart and view the resulting history. Rejection, expiry, cancellation, unavailable drivers, duplicate actions, and stale messages have defined outcomes. One driver cannot serve two concurrent assignments; each trip retains one immutable rideId.

Payments, pricing, ratings, automatic reassignment after acceptance, advanced ETA, and additional UI polish are outside this milestone. This is not a claim that the full commercial product or public launch is ready. Before a pilot, decide who handles interrupted in-progress trips and driver eligibility incidents.

## How to execute small changes

- Treat each numbered item as a candidate issue and normally one focused PR. These are backlog references, not actual ULENDO issue numbers.
- Each PR changes one behavior or contract boundary, includes its relevant regression tests, and describes its own acceptance check. Test-only scaffolding is separate; behavior tests accompany the implementation they verify.
- Keep one implementation task in progress initially. Work in the order below; a dependency explicitly named in a row must also be complete.
- If a task needs unrelated cleanup, multiple new screens, or more than one independent behavior, split it before implementation. Do not refactor both apps wholesale.
- Use the project feature pipeline for each implementation issue: planner, required specialists sequentially, tester, reviewer. Skip/report specialists whose scope is unnecessary. Supply the real issue number before branch creation.
- Backend interfaces and rules land before their app consumers. New v1 functionality remains inactive for users until the coordinated cutover. No intermediate PR permits unguarded client writes or mixed legacy/v1 authority.
- Run affected module checks and targeted acceptance tests. Emulator/rules tests accompany backend behavior. Flutter/model checks accompany changed packages/apps. Do not defer concurrency and authorization tests to the final milestone.
- At every milestone, demonstrate the completed behavior in emulators. Device and deployed-environment verification are separate release gates.

## Contract closure — finish before wire implementation

The agents' contract was coherent but received REQUEST CHANGES. C01–C03 close its three review gaps. C04 closes pending product choices and obtains a new review. Use a fresh pipeline run for revisions; preserve the original review.

| Task | Small change | Owner | Completion check |
| --- | --- | --- | --- |
| C01 | Define role-scoped session restoration, cross-role concurrency, and self-matching policy. | Planner + Firebase + Flutter | One UID used in both apps has unambiguous request, assignment, restoration, and terminal-history behavior. |
| C02 | Define telemetry upload transport, request/acknowledgement fields, session/sequence reset, and server freshness rules. | Firebase + Flutter | Both specialists can implement the same behavior across restart, multiple devices, delayed samples, and heartbeat loss. |
| C03 | Complete online-command and history response envelopes, pagination order/defaults, typed errors, and replay behavior. | Firebase + Flutter | Exact request/response fixtures cover online replay and first/next/empty history pages. |
| C04 | Decide MVP defaults and re-review the complete contract; publish it and acceptance matrix in tracked documentation. | Planner + tester + reviewer; user decides product policy | Contract verdict accepted; cancellation, deadlines, radius, retention, role policy, and interrupted-trip handling recorded. No implementation starts on unresolved wire interfaces. |

Proposed defaults to decide, not assumed approval: rider/assigned-driver cancellation before start; driver cancellation ends the trip; 120-second search; 20-second offers; 30-second presence freshness; 5-km radius; driver-confirmed start/completion. Operational and retention policies also need a decision. No payment flow is assumed.

## Milestone 1 — secure foundations and reliable request/restore

Done when an authenticated rider creates exactly one identity-bearing trip, observes it, restarts the app, and restores the same trip. Matching is not enabled yet.

| Task | Small change | Owner / future paths | Depends on | Completion check |
| --- | --- | --- | --- | --- |
| F01 | Add a reproducible backend emulator/rules test harness and contract fixtures. | Firebase/tester: functions tests, emulator configuration | C04 | Tests run with documented commands and isolated data; unauthenticated and unrelated-account denial cases execute. |
| F02 | Validate the proposed shared transaction boundary before building on it. | Firebase/tester: functions test tooling | F01 | Measure representative retained-state size, contention, and retry behavior; record supported pilot limits and an admission policy. If unsuitable, revise/re-review storage before F05. |
| F03 | Add shared identity-bearing trip/offer models and exact wire fixtures. | Flutter: ulendo_models | C04 | Dart and TypeScript fixtures agree on IDs, enums, nullable fields, coordinates, timestamps, and unknown-schema behavior. Preserve RideRequest as input. |
| F04 | Add common backend command validation, typed failures, and bounded idempotency. | Firebase: functions trip modules | F01, F02 | Same command/payload replays; changed payload is rejected; expired IDs cannot execute; transaction callbacks have no external side effects. |
| F05 | Add atomic requestRideV1 and participant-scoped live reads. | Firebase: functions and RTDB rules | F03, F04 | Distinct concurrent requests admit one ride per rider; same-command retry returns the original rideId; pointers/receipt/work intent commit together; direct client writes denied. |
| F06 | Add role-scoped restoreSessionV1 and getRideV1 live lookup. | Firebase: functions | F05 | Login restores the correct role's assignment/trip; missing records and wrong participants have explicit safe outcomes. |
| F07 | Add shared request/restore/watch transport and durable command retry. | Flutter: ulendo_core | F03, F06 | Persist command before sending; lost response/restart reuses its exact ID/payload; restore bootstraps server time; stale responses cannot regress state. |
| F08 | Connect rider request and restoration to saved snapshots. | Flutter: rider trip management/shell | F07 | Rider retains rideId, shows searching only after the authoritative result, and restores the same ride after restart. Null/error does not invent completion or lose known identity. |

F02 is a go/no-go experiment, not an invitation to build a generalized workflow framework. Prefer the smallest design that meets the pilot's measured limits. F05 work intents are persisted but no dispatch consumer is enabled until Milestone 2.

## Milestone 2 — safe driver offers and acceptance

Done when an eligible online driver discovers an offer without relying on push delivery, accepts it, and both apps observe the same accepted ride. Competing riders cannot reserve the same driver.

| Task | Small change | Owner / future paths | Depends on | Completion check |
| --- | --- | --- | --- | --- |
| O01 | Separate trusted eligibility/online intent from telemetry. | Firebase: functions, rules | F04, F06 | Only trusted administration changes eligibility; online/offline is validated and replay-safe; clients cannot grant themselves driver privileges or assignment state. Profile privilege fields are protected. |
| O02 | Implement the agreed telemetry ingestion and private presence storage. | Firebase: telemetry modules/rules | O01, C02 | Server timestamps and sequence/session guards work; location cannot change online intent or assignment; tokens are private. |
| O03 | Connect driver online/offline and telemetry publication. | Flutter: driver services/business logic, shared core where reused | O02, F07 | Busy/reserved drivers are not made available by GPS; online cycles dispose listeners; restart restores online/assignment information. |
| O04 | Add durable work claiming, fenced retries, and reconciliation primitives. | Firebase: work modules | F05 | Committed work survives worker restart; stale leases cannot acknowledge; duplicate processing has no duplicate business effects. |
| O05 | Match one eligible candidate and atomically issue a persisted offer. | Firebase: dispatch modules/rules | O02, O04 | Nearest eligible candidate within radius is considered across geohash boundaries; one reservation per driver; own offer readable, other offers/private trip data denied. |
| O06 | Add acceptOfferV1 with identity, deadline, actor, and version guards. | Firebase: offer command module | O05 | Exact offer acceptance commits trip/offer/assignment together; old, expired, foreign, and racing acceptance attempts have no partial effects. |
| O07 | Connect driver offer subscription and accept action. | Flutter: shared core, driver rides/notifications/shell | O03, O06 | Offer appears from saved state with FCM disabled; accept waits for persisted confirmation; one route per offer; logout disposes listeners. |
| O08 | Render rider acceptance and assigned-driver information. | Flutter: rider trip management/presentation | O07, F08 | Both apps show the same rideId/status/assignment; reconnect and late search responses cannot revert accepted state. |

## Milestone 3 — arrival, start, completion, and history

Done when both apps observe the full successful lifecycle and two successive trips produce separate history records.

| Task | Small change | Owner / future paths | Depends on | Completion check |
| --- | --- | --- | --- | --- |
| L01 | Add arriveAtPickupV1 and wire driver action/rider observation. | Firebase then Flutter: trip commands, both apps | O08 | Only assigned driver can move accepted → arrived; both apps observe the saved timestamp/version; no local-only progress. |
| L02 | Add startRideV1 and wire both apps. | Firebase then Flutter: trip commands, both apps | L01 | Only arrived → in_progress succeeds; duplicates/races and skipped milestones are covered. |
| L03 | Add atomic completion, terminal pointer release, and archive work intent. | Firebase: terminal command module | L02, O04 | Only in_progress → completed; exact ride/assignment pointers released once; new trip can start without waiting for archive. |
| L04 | Add idempotent terminal archive and conditional retention cleanup. | Firebase: history worker/rules | L03 | Separate Firestore document per rideId; business timestamps stable; archive failure retains live terminal; old cleanup cannot clear a new trip. |
| L05 | Add participant history lookup/listing and terminal restore fallback. | Firebase: history/read modules | L04, C03 | Correct role-scoped pagination; unrelated users denied; absent live trip resolves to history; missing both is explicit. |
| L06 | Connect completion, terminal recovery, and minimal history in both apps. | Flutter: shared core, rider/driver screens | L05 | Each participant sees completion and own history after restart/live cleanup; two rides stay distinct; terminal updates do not displace a newer active ride. |

L01/L02 are intentionally small cross-stack slices. Each uses sequential Firebase then Flutter specialists and ends in a visible, testable capability. Avoid combining arrival, start, and completion into one PR.

## Milestone 4 — failure recovery and safe tracking

Done when a trip either advances or reaches a defined terminal outcome, even with rejection, timeout, cancellation, missed push, and service restarts.

| Task | Small change | Owner / future paths | Depends on | Completion check |
| --- | --- | --- | --- | --- |
| R01 | Add offer rejection and driver decline UI. | Firebase then Flutter: offers/driver rides | L06 | Rejection releases only the matching reservation; trip remains searching; decline persists and does not reopen the same offer. |
| R02 | Add expiry, offline withdrawal, rematching, and search exhaustion. | Firebase: scheduler/dispatch; Flutter outcome rendering | R01, O04 | No candidate, rejected offers, and missing tokens reach retry or no_driver_found; expiry is enforced even if cleanup runs late; accepted trips survive disconnect. |
| R03 | Add rider cancellation for allowed pre-start states. | Firebase then Flutter: trip command, rider UI | R02 | Search/accepted/arrived cancellation follows contract; pending offer withdrawn; acceptance race has one valid outcome; no optimistic success. |
| R04 | Add assigned-driver cancellation before start. | Firebase then Flutter: trip command, driver UI | R03 | Rider observes terminal cancellation, reservation released, no automatic reassignment; in-progress cancellation rejected per approved policy. |
| R05 | Add participant-safe live location projection and rider tracking. | Firebase then Flutter: telemetry projection/rules/shared core/rider UI | O02, R04 | Current participants only; stale/foreign/out-of-order samples rejected; location access ends at terminal state; telemetry never changes trip phase. |
| R06 | Add push delivery as an optional hint. | Firebase then Flutter: notification worker/shared messaging/driver integration | R05 | Missing/duplicate/delayed push cannot strand an offer, reopen routes, or change a newer ride; stream/restore remains sufficient. |

## Milestone 5 — pilot release gate

Done when the new flow is proven on devices and the coordinated migration has been rehearsed. No public production rollout is implied.

| Task | Small change | Owner / future paths | Depends on | Completion check |
| --- | --- | --- | --- | --- |
| P01 | Fix rider onboarding save-failure handling. | Flutter: rider shell/profile UI | R06 | Failed profile save retains form and does not bypass onboarding; targeted regressions pass. |
| P02 | Fix permission-settings recovery. | Flutter: rider permissions UI | P01 | Settings action opens the platform settings; return/recheck updates permission state without duplicate listeners. |
| P03 | Add minimal operations visibility and pilot support runbook. | Firebase + planner: structured logs/work health/docs | P02 | Correlate rideId/offerId/commandId without private payload logging; identify overdue work/archive failures; documented operator for interrupted trip and eligibility incidents. Any recovery mutation needs its own guarded/tested task. |
| P04 | Execute full conformance and two-device smoke checks. | Tester + reviewer | P03 | Run the 35-scenario matrix plus C01–C03 cases; restart/reconnect, denied access, concurrent riders, successive history, and controlled outage checks have recorded evidence. Resolve failures in separate focused fixes. |
| P05 | Rehearse legacy cutover and rollback in a staging environment. | Firebase + Flutter + tester | P04 | Back up/inventory old records; drain/resolve legacy rides; minimum-version gate; disable old writers; verify no mixed authority or invented history. Rehearse rollback without reviving stale actions. |
| P06 | Review and authorize controlled pilot activation. | Reviewer + user | P05 | Security, capacity, supported devices, worker availability, operating policy, and cutover evidence accepted; user makes release decision. Merging/deployment remains a separate action. |

## First work queue

1. C01: role-scoped restoration and cross-role policy.
2. C02: telemetry upload/session ordering contract.
3. C03: online/history response schemas.
4. C04: settle defaults, re-review, publish durable contract.
5. F01: backend conformance harness.
6. F02: validate transaction feasibility before committing to it.

Do not create implementation branches or assign real issue IDs until the corresponding issue exists. Do not use the earlier ULENDO-8 ID for unrelated new tasks.

## Inputs and evidence limits

The earlier agent run lives at `.pipeline/2026-11-18-trip-contract/`: spec.md, contract.md, changes-firebase.md, changes-flutter.md, changes.md, tests.md, and review.md. It is Git-ignored; publish approved normative documents to tracked `docs/` paths in C04 so future work does not depend on local artifacts.

The existing assessment confirmed source-level gaps, not deployed Firebase behavior. The contract is proposed and unimplemented. No runtime, device, emulator, or load tests were executed to create this plan. Task order expresses dependencies, not time estimates or promised production capacity.
