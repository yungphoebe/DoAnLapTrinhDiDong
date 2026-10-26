# Google sign-in implementation plan

**Goal:** Select a Google account on the existing Flutter web login screen and enter the app with a server-issued session.

**Architecture:** Render the official Google Identity Services button. Send its ID token to ASP.NET, validate the Google signature, issuer, audience and expiry, then use Identity external login provider/subject to return the existing app JWT. No Gmail password or Google access token is requested.

**Constraints:** Keep password login working. OAuth Web Client ID must be supplied by the project owner. Do not automatically merge accounts by matching email. No external deployment or account creation in Google Cloud is authorized or required for implementation.

- [x] Add failing API tests for missing configuration, invalid tokens, new/returning users, duplicate email and unverified email; add cryptographic verifier tests.
- [x] Implement Google options, verifier and controller; verify the API tests pass.
- [x] Add the official GIS web button with a conditional native fallback and connect AuthService/session/navigation. Test bridge callback and loading failures.
- [x] Document Google Cloud origins/configuration; run analyze, focused tests and web build, then restart local services.

**Review focus:** forged/expired/wrong-audience tokens, repeated sign-ins, account conflicts, missing Client ID, disposed login screens and unavailable Google script. Full interactive Google login remains dependent on a real OAuth client and user consent.

## Verification

- New backend tests: 8 pass (signed RSA tokens validate; forged/expired/wrong-audience/wrong-issuer reject).
- Entire backend suite: 64 pass, 6 SQL integration tests skipped without AIGYM_TEST_SQLSERVER. One initial run aborted during low-memory contention; sequential rerun passed.
- JS bridge: 4 pass, including delayed DOM attachment and retry after script-load failure.
- `flutter analyze --no-pub lib`: no issues.
- `flutter build web --no-pub --no-wasm-dry-run -O1 --output E:\TempFlutter\ai-gym-google-web`: success. Output on E because C is nearly full. Initial concurrent analyzer attempt crashed due system resource exhaustion; sequential analyze passed.
- Local backend: missing Client ID returns expected 503; original password demo login still succeeds.
- Independent read-only review: no Critical/Important findings.
- Remaining external prerequisite: user's actual OAuth Web Client ID, authorized localhost origins and interactive Google consent. No real Google login claimed.
