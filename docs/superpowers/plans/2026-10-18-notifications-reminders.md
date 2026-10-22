# Notifications and reminders implementation plan

> **For agentic workers:** Use superpowers:executing-plans, implement inline task by task. The user explicitly requested implementation; continue without another approval round.

**Goal:** Persistent account notifications with configurable Android local reminders and Chrome Web Push.
**Architecture:** SQL settings/inbox plus a background dispatcher; Flutter controller with platform adapters and one notification route resolver.
**Tech Stack:** ASP.NET Core 9/EF Core SQL Server, WebPush, Flutter, flutter_local_notifications/timezone/flutter_timezone, service worker.
**Spec:** `docs/superpowers/specs/2026-10-18-notifications-reminders-design.md`.

## Constraints

- Defaults off; workout daily 18:00, water 09:00–21:00 every 120 minutes, weekly Sunday 20:00.
- JWT ownership, no fabricated metrics, preserve existing uncommitted changes.
- Android local schedule only, Chrome backend push only; off cancels current device immediately, remote Android changes apply on resume.
- Inline execution in current checkout (existing project plan requests no worktree). Product changes stay uncommitted for user review.

## Review focus

- Account switch and delayed pushes must not expose another account's notifications.
- Failed save of an off switch must still block local reminders until retry.
- Concurrent scheduler runs must not duplicate events or deliveries.
- Permission denial, unavailable backend and expired subscriptions must remain recoverable.
- Cold notification launch must restore auth before routing and validate its account.

## Task 1 — Settings/inbox and schedule engine

Files: Models/ReminderSettings.cs, UserNotification.cs, WebPushSubscription.cs; Data/NotificationSchema.cs; Dtos/NotificationDtos.cs; Services/ReminderSchedule.cs, NotificationScheduler.cs; Controllers/NotificationsController.cs; ApplicationDbContext/Program/DatabaseSeeder.
Interfaces: `ReminderSchedule.Occurrences(ReminderSettings, DateTime fromUtc, DateTime toUtc)`; `NotificationScheduler.TickAsync(DateTime utcNow)`; GET/PUT settings, paginated inbox, idempotent read/read-all.
- [x] Add failing API ownership/settings/read tests and fixed-clock schedule tests; run dotnet test.
- [x] Implement validated schedules, idempotent SQL event insertion and existing-database upgrade; test disabled/revised schedules, timezones and concurrent ticks.

## Task 2 — Web Push dispatch

Files: Services/NotificationPush.cs, NotificationWorker.cs; web/notification-worker.js, web/notification-bridge.js, web/index.html; .gitignore and backend README.
Interfaces: push-key/subscriptions endpoints, `NotificationPush.SendPendingAsync`, JS bridge request permission/register, applySettings, deactivate.
- [x] Test HTTPS host/key validation, owner deletion and stable event IDs. Expired endpoint handling is implemented; real provider responses remain unverified.
- [x] Implement persistent VAPID keys in ignored local data, bounded retry, permission gesture flow and worker push/click handling.

## Task 3 — Flutter model/controller and Android adapter

Files: lib/notifications/{models,api,controller,platform,platform_native,platform_web}.dart; auth/main lifecycle; Android manifest/build/drawable.
Interfaces: `NotificationController.load`, `save(ReminderSettings)`, `logout`, `markRead`, `NotificationPlatform.apply(settings, userId)` and `activate(userId, requestPermission)`.
- [x] Add failing fake-adapter tests for persistence, cancel on disable, failure block, refresh, account switch, cold routes.
- [x] Implement Android recurring inexact schedule IDs per kind/day/slot and web conditional adapter; request permission only after button/toggle gesture. Cancel on logout, sync on resume.

## Task 4 — UI and routes

Files: notifications inbox/settings/destination screens, settings.dart, home.dart, main.dart.
- [x] Verify inbox/read behavior through API tests, failure/save/route behavior through controller tests, cold start through a widget test, and existing settings tests. Full interactive inbox/schedule UI walkthrough remains unavailable.
- [x] Wire bell, unread badge, existing toggles, editable schedule, login continuation and real logout.
- [x] Add workouts/water/week destination pages with truthful empty states.

## Task 5 — Verification and review

- [x] Run formatter/analyzer, targeted/full Flutter tests, dotnet tests including isolated SQL Server, Flutter web build and Android debug build if toolchain available.
- [x] Verify JS worker behavior and attempt browser runtime; report unavailable real OS/browser push checks accurately.
- [x] Independent fresh review, fix important issues, update ledger and README run/setup instructions.

## Execution ledger

- 2026-10-19: User added Help/Feedback/Terms and confirmed no official content supplied. Added nullable group content API, true package version, authenticated/idempotent persisted feedback with success/failure UI; no invented policies.
- Task 1/2: API and schedule tests RED (404) -> GREEN. Backend suite 16/16 including SQL Server schema upgrade and concurrent schedule deduplication; worker behavior tests 4/4.
- Task 3/4: Controller regressions RED -> GREEN for expired session, old account save, local-off retry block, device failure vs saved config, logout cleanup. Support UI tests confirm missing content/version and retry acknowledgement.
- Ruling: test build uses .artifacts/notifications because user's API process locks its default executable; do not stop the user's running backend.
- Ruling: Windows symlink creation is unavailable in this session; dependencies resolved and web/Android builds use --no-pub. No machine-wide Developer Mode changes were made.

- Ruling: user's “triển khai đi” approves moving directly through plan to implementation; no additional design approval questions.
- Ruling: scope is the notification spec; community connection spec remains unimplemented.

- Final backend run: 17/17 passed, including isolated SQL Server schema upgrades, concurrent ticks, persisted feedback and account ownership.
- Flutter: analyzer reports no issues; all 11 notification and 3 support tests pass. Full suite: 54 passed, 5 failed. The same 5 failures occur in the earlier community-likes-full-test.log (demo auth expectations and the old hard-coded community counter).
- Independent review found stale load/save races, timezone sync, delayed permissions after logout, and offline cold-start cancellation. Each issue was reproduced with a failing test and fixed; all 11 notification tests then passed.
- Browser automation reported Browser not available: chrome. Worker push/click behavior passes 4 Node tests, but actual OS push delivery and a two-device walkthrough are not claimed.
- Android build diagnostics proved native JVM allocation failure with the template's 8 GB heap on an 8 GB machine. Reduced heap to 2 GB, limited Gradle workers and used in-process Kotlin; disabled Kotlin incremental caching because project E: and pub cache C: caused cross-root cache failures.
- Final web build succeeds with the new notification bridge/store/worker included. The build retains the existing missing Cupertino font warning; no Cupertino icon usage was added.
- Final Android debug build succeeds after the documented memory/cache fixes; APK is build/app/outputs/flutter-apk/app-debug.apk. Real-device notification permission, delivery and tap navigation remain manual acceptance checks.

## API contract audit, 2026-10-20

- User narrowed the next check to inbox/read/settings/feedback and event deduplication; preserve the already approved Chrome Web Push design, add no push provider.
- Added NotificationSupportContractTests: pagination including timestamp ties, unread counts, read-all ownership/idempotency, persistent read times, anonymous access, settings revision conflicts and disabled settings, feedback ownership/retry/validation.
- These 3 HTTP contract tests passed immediately against existing endpoints; no replacement APIs were needed.
- SQL UTC regression failed: ScheduledAtUtc read as DateTimeKind.Unspecified because datetime2 does not store Kind. Applied UTC read converters to notification ScheduledAtUtc/CreatedAt/ReadAt and feedback CreatedAt; no schema/data rewrite.
- Final verification: 27/27 backend tests passed, none skipped, using AIGYM_TEST_SQLSERVER and --artifacts-path .artifacts/notifications. Includes 8 concurrent scheduler ticks producing one event, stop-after-disable and all comment/like tests. UTC read-back assertions now pass.
- Updated backend README with endpoint contracts, revision handling and push scope. git diff --check passed. No frontend or provider configuration changes in this audit.
- Independent review of UTC converters and new tests found no critical/important issues. Minor coverage note: notification CreatedAt.Kind is not separately asserted; exposed ScheduledAtUtc/ReadAt and feedback acknowledgement CreatedAt are covered.
