# AI GYM Flutter UI

**Goal:** Implement the twelve supplied Vietnamese mobile screens with the dark/purple appearance and working local UI interactions.

**Architecture:** Standard Flutter Material widgets, a small shared theme/widget file, Navigator routes, and local StatefulWidget state. No backend, authentication service, actual camera analysis, or AI integration is in scope. Mobile layout fills its viewport; wide screens show a centered phone-width canvas.

**Reference:** User-supplied screenshots in this conversation. Background #111111, cards #1E1E1E, accent #983BFA, muted gray text, thin borders and rounded controls. Use bundled illustrative fitness photos since original image files are not supplied.

## Tasks

- [x] Bootstrap Android/iOS/web Flutter project and shared theme (`lib/main.dart`, `lib/ui.dart`).
- [x] Add behavior checks before implementation: form validation and registration/onboarding flow (`test/auth_flow_test.dart`), navigation/settings, camera pause/end, community controls (`test/app_flow_test.dart`).
- [x] Implement login, registration, password reset (`lib/screens/auth.dart`) and three onboarding steps (`lib/screens/onboarding.dart`).
- [x] Implement dashboard and camera demo (`lib/screens/home.dart`, `lib/screens/camera.dart`).
- [x] Implement AI coach and community/PT (`lib/screens/coach.dart`, `lib/screens/community.dart`).
- [x] Implement app shell and settings/coach preferences (`lib/screens/shell.dart`, `lib/screens/settings.dart`).
- [x] Bundle images, document run commands and demo limitations in `README.md`.
- [x] Run formatter, `flutter analyze`, `flutter test`, `flutter build web`; visually inspect mobile screenshots and review code.

## Shared interfaces

- `MainApp` is the root MaterialApp; `/login`, `/register`, `/forgot`, `/onboarding`, `/home`, `/camera`, `/settings`, `/coach-settings` are registered routes.
- `GymColors`: `background`, `surface`, `border`, `purple`, `muted`, `green` color constants.
- `GymCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16), Color? color})`.
- `PrimaryButton({required String label, required VoidCallback? onPressed, IconData? icon})`.
- `SectionHeading({required String title, String? action, VoidCallback? onAction})`.
- `showMessage(BuildContext context, String message)` displays a SnackBar.
- `HomeScreen`, `CoachScreen`, `CommunityScreen` are shell tab bodies (no bottom navigation of their own).
- `CameraScreen` owns its full-screen Scaffold.
- Assets: `assets/images/workout.jpg`, `assets/images/community.jpg`, `assets/images/trainer.jpg`, `assets/images/avatar.jpg`.

## Review focus

Empty/invalid forms stay on their screen; back navigation preserves onboarding choices; no overflow at 320px width or with keyboard; tab switching preserves local state; settings save/cancel behavior is explicit. No control claims to perform a real network or health action.

## Decisions

Proceed from the user's supplied designs and explicit request to code. Do not create a worktree or require additional design approvals. Split independent screen implementation between agents and request an independent review after integration.

## Verification results

Formatter clean, analyzer reports no issues, 14 widget tests pass, all 12 real-font previews render without exceptions, and web build succeeds. Independent review found no critical/important issues; camera icon contrast and chat/FAB spacing were corrected. iOS and Android binaries were not built. Web compilation emits a framework CupertinoIcons font warning; app controls use bundled MaterialIcons and are present in rendered previews.
