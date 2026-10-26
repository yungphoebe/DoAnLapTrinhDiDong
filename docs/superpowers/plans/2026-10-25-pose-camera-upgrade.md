# Pose camera upgrade plan

Goal: Count reps and correct form on Android like Chrome, improve recognition on both, and speak Vietnamese rep counts and form cues.

1. `lib/services/pose_rules.dart`: Dart port of `web/pose_rules.mjs` (same thresholds, codes and summary shape). Upgrades on both sides: light landmark smoothing, partial-range cues (`squat_shallow`, `pushup_shallow`, `biceps_partial`), and a per-rep event (`repEvent`: `correct`/`incorrect`) for the voice. Tests: `test/pose_rules_test.dart`, `test/pose_rules_test.mjs`.
2. `lib/screens/pose_camera_mobile.dart`: camera image stream (NV21) → `google_mlkit_pose_detection` on the device → rules → skeleton overlay, counters and cues → `flutter_tts` vi-VN → `ProfileService.saveWorkout` with exercises and feedback counts, so challenges advance.
3. `pose_camera_native.dart`: Android/iOS use the mobile screen; Windows keeps the LM Studio screen.
4. Web voice: rep counts are always spoken (short), and cues are throttled, with start/finish phrases.

Limits: heuristics in image space, not a clinical assessment. The voice quality depends on the Vietnamese TTS voice installed on the device. There are two implementations of the rules (Dart and JS), and they must be changed together.

Verification: Dart and JS rule tests, the analyzer, and an Android debug build. Device delivery is untested unless it is run on a phone.
