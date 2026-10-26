# Training bot implementation plan

Goal: Upgrade the existing GYM BUDDY with opt-in teasing, progress-aware messages and actionable reminders. Keep the existing notification infrastructure and user edits.

Approach: Fixed messages selected from actual workout progress; no AI dependency. Store the teasing preference with account reminder settings. Android recurring reminders use conditional copy because progress is unavailable at delivery; server notifications check today's saved workouts.

1. Add failing Flutter checks for unknown progress, short completed sessions, streak reminders, tone persistence and notification navigation. Add backend checks for preference round trips and progress-aware notification generation.
2. Extend `lib/notifications/models.dart`, backend `Models/ReminderSettings.cs`, `Dtos/NotificationDtos.cs`, and `Data/NotificationSchema.cs` with a default-off teasing switch; preserve existing databases with an additive column.
3. Update `lib/screens/training_bot.dart`, `lib/notifications/settings_screen.dart`, and native reminder copy. Reuse profile loading, notification settings and camera navigation. Implement messages in `lib/notifications/training_bot_copy.dart` for focused testing.
4. Update `Services/ReminderSchedule.cs` and `NotificationScheduler.cs` to honor tone and congratulate users whose workouts are saved today. Route workout notifications to the camera.
5. Run focused Flutter tests, analyzer, backend notification tests and web-worker tests. Review the diff. Do not alter unrelated pending changes or create a worktree.

Limits: No new step-goal, badge or weekly-summary system. Existing Android OS scheduling and Chrome push permission requirements apply. No claim of delivery testing without a device.

Verification: 17 focused Flutter tests (including the settings interaction), 7 isolated backend bot/schedule tests, and 4 web notification worker tests pass. Analyzer reports no issues in the changed Flutter files. Review found a cross-midnight catch-up bug; a failing regression test reproduced it before fixing the date calculation.

Full backend tests remain blocked by duplicate `_databaseName` declarations in the existing `ApiFactory`. Focused backend tests ran from a temporary project with a separate output directory because the running API locks its normal binaries. No live SQL upgrade or physical-device delivery was tested. Restart the API with the new build before using the persisted tone setting.
