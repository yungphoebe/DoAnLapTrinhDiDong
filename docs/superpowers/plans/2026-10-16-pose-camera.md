# Chrome pose camera implementation plan

Approved: Chrome first; skeleton, automatic recognition within Squat/Push-up/Jumping Jack, complete-cycle reps, rule feedback, voice toggle, account-owned history. Universal exercise recognition and long-term personalization deferred.

Architecture: same-origin camera page embedded in Flutter on web. MediaPipe Tasks Vision 0.10.32 Pose Landmarker Lite processes frames on-device; no video upload. A pure JS rule engine handles temporal classification and counting. The Flutter parent retains authentication and saves validated aggregate summaries through existing backend endpoints. Native route keeps the existing image-feedback camera, clearly outside Chrome pose scope.

1. `web/pose_rules.mjs`, `tool/pose_rules.test.mjs`: red/green tests for three exercises, complete-cycle hysteresis/dwell, missing landmarks, invalid geometry, confidence, classification changes, bad-form episodes.
2. `web/pose_camera.html`, `web/pose_camera.mjs`: real camera + canvas overlay, model error recovery, pause/background/dispose lifecycle, bounded frame rate, voice cooldown, frozen retry payload and save acknowledgement. Load dependency/model only on camera action.
3. `lib/screens/pose_camera*.dart`, history screen, `profile_service.dart`, routes: same-origin/source-checked iframe bridge; never pass JWT to page; persist only to captured account; show recent session details.
4. Backend workout model/DTO/controller/migration: optional per-exercise reps and error counts, strict validation and account-scoped latest50 history; maintain old session compatibility and idempotency.
5. Run JS tests, backend tests, targeted Flutter tests, analyze, web build; reviewer pass; restart backend/app after additive migration. Browser integration smoke tests for model loading and camera lifecycle if environment supports headless Chrome. Physical exercise accuracy still requires real-person trials.

Counting is geometric heuristic, not a claim of clinical safety: angle checks are view-dependent, missing tracking resets partial motion, and uncertain poses do not get fabricated reps. Squat/push-up use side view; jumping jack uses front view. UI explains the expected views.

Reference: https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/web_js
