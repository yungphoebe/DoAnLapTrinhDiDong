# Floating gym pet

User correction: GYM BUDDY should be an in-app mascot with speech bubbles, not only a notification screen. User selected a purple gym robot.

Design: Attach a compact floating pet to AppShell's existing tab body. It greets on entry, toggles a speech bubble on tap, and celebrates saved workouts. Bubble actions open the existing camera/history and reminder settings. It stays below routes such as camera and settings, and hides while the keyboard is open. Reuse existing progress and tone settings. Draw the robot with Flutter so it needs no package or image download.

Alternative: A global overlay would follow every route but requires route exclusions and could obstruct workouts. Use the shell overlay for this first implementation.

Steps:
1. Write widget tests for greeting, collapse/reopen, actions, completed-workout updates and small-screen layout; confirm failure.
2. Add `lib/widgets/training_pet.dart` with the robot and bubble. Integrate into `lib/screens/shell.dart` and reuse the robot in `lib/screens/training_bot.dart`.
3. Run focused widget and existing navigation/bot tests, analyzer and a visual render check. Review only this change.

No new backend, notifications, chatbot service or dependencies are needed.

Verification: Five pet widget tests cover actual shell navigation, collapse/reopen, actions, celebration and 320px layout at 2x text scale. Rendered and visually inspected the actual home screen at 402px; preview is `build/training_pet_preview.png`. Review caught a refresh-induced repeated celebration; keep the last known completion state during loading.

Broader checks: `app_flow_test.dart` fails on absent community data; reproduced the identical failure using the original shell without the pet. `home_camera_test.dart` has two failures in its existing 320px camera and nutrition-route fixtures (those tests do not mount the changed shell). No physical-device run performed.
