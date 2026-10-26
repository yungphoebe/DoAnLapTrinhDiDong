# Account profile implementation plan

Approved scope: persist account identity, body settings and completed camera sessions in SQL Server. New accounts have no fabricated measurements or progress. Unknown distance/nutrition stay unavailable.

1. Backend (`Models/ApplicationUser.cs`, new workout model, `Data/ApplicationDbContext.cs`, profile controller/DTOs and migration): authenticated profile read/update and idempotent session save, using JWT user identity. Test new accounts, validation, isolation, duplicate saves and login persistence before implementing.
2. Flutter (`services/profile_service.dart`, `services/auth_service.dart`, `screens/auth.dart`, `screens/home.dart`, `screens/settings.dart`, `screens/onboarding.dart`): shared observable profile loaded from API, reset on session change; render saved identity/settings and truthful empty states; persist edits and onboarding. Test delayed responses after logout and failed saves.
3. Camera (`screens/camera.dart`): save actual active elapsed time on explicit finish, keep failed save retryable with the same session ID, update home after successful save. Do not infer distance/calories/repetitions.
4. Verify backend suite, targeted Flutter regression tests, analyze and web build. Independently review changes, apply additive SQL migration through app startup, restart backend and Flutter, and smoke-test API.

Constraints: preserve existing working-tree edits; no worktree, dependency additions or destructive SQL. Workout day summaries use Vietnam UTC+7. No fabricated imported history. Only completed recorded sessions count toward streak.
