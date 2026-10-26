# iOS unsigned IPA implementation plan

**Goal:** Implement the user's GitHub → Codemagic macOS → unsigned release IPA → Sideloadly on Windows workflow.

**Architecture:** Keep the existing Flutter app and native iOS project. Use stable Flutter/latest Xcode with CocoaPods and the existing Swift Package Manager integration. Package the device build without signing; signing is exclusively a local Sideloadly operation.

**Constraints:** No dependency upgrades, Android changes, Apple signing credentials, automatic publishing, or claims of a verified macOS build from Windows. The Flutter project is the nested directory containing pubspec.yaml; that directory must become the GitHub repository root. The supplied user request is the implementation specification and authorizes direct execution.

## Tasks

- [x] Audit SDK, lockfile, native plugin manifests, deployment targets, permissions, capabilities and endpoint configuration.
- [x] Add regression tests for an optional HealthKit fallback on iOS, preserving normal builds and Android.
- [x] Add iOS CocoaPods configuration and missing speech permission. Retain original HealthKit entitlement by default; only clear it in the disposable CI checkout when fallback is explicitly enabled.
- [x] Create macOS packaging script with intact app copy and structural IPA validation. Test valid and invalid ZIP fixtures on Windows.
- [x] Create ios-unsigned-ipa workflow, explicit backend URL check, unsigned release device build and artifact collection.
- [x] Remove existing SMTP password from tracked configuration before documenting GitHub upload; preserve it in local .NET User Secrets and ignore private credentials/signing files.
- [x] Write Vietnamese guide including project audit, capabilities, free-tier limits, backend networking, GitHub setup, Codemagic steps, Sideloadly installation, renewal and troubleshooting.
- [x] Validate YAML against Codemagic schema, plist XML, Bash syntax, Python ZIP tests, focused Flutter tests and analysis. Record unverified macOS/iPhone steps.

## Review focus

- App folder and repository root must coincide when uploading; Codemagic discovers YAML at repository root.
- Reject simulator output, missing executables, malformed ZIPs and unsafe archive paths.
- HealthKit flag must not change Android or normal iOS builds.
- An iPhone cannot use Android emulator loopback or the Windows localhost endpoint.
- Existing secrets and generated files must not be staged for GitHub.

## Execution record

Initial audit: Flutter 3.47.5 stable / Dart 3.13.4; pubspec SDK ^3.13.4; iOS 15.0; bundle com.aigym.aiGym; existing SPM project, missing Podfile; HealthKit entitlement present; speech usage description missing. No .git repository exists in either workspace directory. Native macOS tools are unavailable on Windows.

Ruling: The current official Apple capability table explicitly permits HealthKit for the free Apple Developer account category. Keep it enabled by default; provide IOS_DISABLE_HEALTHKIT only as an optional signing fallback, not as a free-account requirement.

Verification: official YAML schema, Bash and plist checks passed; 4 Python tests and 9 Flutter Health/API tests passed; backend builds without warnings/errors. Existing voice settings test fails at its saved-label assertion even with the original health message branch. Independent review found no critical/important issue. Detailed limits and file manifest are recorded in docs/ios-ci-verification.md.
