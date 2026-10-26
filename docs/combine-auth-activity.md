# Combined authentication and workout/activity branch

Requested branch: `feat/combine-auth-activity`.

Sources:

- `feat/auth` at `7fc0731e01c3897649b3e8e2aa696f84643e5419`.
- `feat/ai-gym-workout-activity` at `24682fc0ea34226b37426ce361249c31fc99890c`.

The merge keeps both parent histories. Since feat/auth was uploaded as a source
snapshot on the initial UI commit, shared source files were compared against
the workout branch's predecessor `1815d9d` to resolve add/add conflicts without
discarding either set of changes.

## Preserved and combined behavior

- Google sign-in, existing password sign-in, session storage and account profile.
- Challenges, medals, friend competition, community, notifications and support.
- Walking/running sessions, routes, daily activity goals and running reminders.
- Saved workout plans, planned exercise results, camera set targets and rest periods.
- Vietnamese camera speech, test control and mute behavior.
- Updated native dependencies and unsigned iOS packaging configuration.

## Integration corrections

- Running reminder migration safely handles databases whose notification table
  has not been created. The schema helper also upgrades existing notification
  tables with the new running fields.
- Camera set completion/rest uses the current performance timestamp.
- Camera sessions from static home recommendations save ordinary history;
  only exercises with persistent plan identifiers save plan-linked results.
- Settings shows one persisted reminder control and one functional health row,
  rather than contradictory demo controls.
- Google configuration and LocalDB development settings are retained. SMTP
  credentials remain empty and must be supplied outside source control.

## Verification

- Backend with real temporary SQL Server databases: 75 passed, none skipped.
  Includes fresh database startup, legacy upgrade preserving accounts, Google
  session saving activity/workout history and account isolation.
- Google bridge, notifications, session, voice and combined camera flow:
  18 JavaScript tests passed.
- Synthetic iOS archive validation: 4 Python tests passed. This is not an iOS build.
- `flutter analyze --no-pub`: no issues.
- Web build succeeded with `--no-wasm-dry-run -O1`, output in
  `E:\TempFlutter\aigym-combined-web` on the verification machine.
- Full Flutter suite: 94 passed, 13 failed. It still contains failures in old demo-flow
  expectations, nutrition and device-info test mocks. These are not hidden or
  disabled; they are separate from the API and camera integration checks.
- Physical camera/GPS, actual Google consent and native Android/iOS execution
  still require user devices and platform permissions.
