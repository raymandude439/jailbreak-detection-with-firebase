# App Integrity Lab

A small Flutter workshop for Android and iOS: local jailbreak/root detection → Firebase App Check → a Dio request carrying `X-Firebase-AppCheck` → a server decision.

One dashboard runs a check at launch, on foreground resume, and on demand. It has jailbreak/root **simulation** controls, a non-fatal error test, and an intentional native crash. Compromise shows “Ooops you are jailbroken/rooted” with a Rick Astley GIF. A server block without local compromise uses a neutral access-blocked message.

## Firebase workshop setup

Follow the [modular Firebase setup guide](docs/FIREBASE_SETUP.md) for instructor preparation, native app registration, debug App Check, Crashlytics, API deployment, and optional real attestation. It includes a project-values worksheet, acceptance checks, and troubleshooting. The core workshop is modules 1–3; add module 4 for the API and module 5 for platform attestation.

## Start without a Firebase project

Requirements: Flutter compatible with Dart 3.12.2+, Android SDK/JDK 17 for Android, or macOS/Xcode for iOS. Current Firebase dependencies require Android API 23+ and iOS 15+. Use physical devices for meaningful detection testing; emulators can produce false positives.

```sh
flutter pub get
cp .env.example .env
flutter run --dart-define-from-file=.env
```

The default is **local workshop mode**: no Firebase configuration needed, no fake App Check tokens, no API calls, and no server approval claimed. Native detection still runs. The GIF is fetched from Giphy and has an offline fallback.

`.env` is a **JSON file** consumed by Flutter's `--dart-define-from-file`, not a shell dotenv file. Rebuild/restart after changing it. Do not `source .env`. These values are compiled into the app and are not secrets.

| Key | Default | Purpose |
| --- | --- | --- |
| `FIREBASE_ENABLED` | `false` | Initialize attendee-owned native Firebase configuration |
| `APP_CHECK_DEBUG` | `true` | Use registered debug providers; release builds reject this setting when Firebase is enabled |
| `CRASHLYTICS_ENABLED` | `true` | Enable Crashlytics collection after Firebase initializes |
| `ENABLE_TEST_CONTROLS` | `true` in the example | Show simulations and intentional error/crash controls; set `false` for distribution |
| `API_BASE_URL` | blank | Deployed function URL, **without** `/integrity`; HTTPS only |
| `RICK_ASTLEY_GIF_URL` | Giphy URL | Replace with an attendee-hosted Rick Astley GIF if needed |

## Connect your Firebase project

1. Create a Firebase project and register Android and iOS applications. The starter application IDs are `com.rayhanwibowo.jailbreak_detection_with_firebase` (Android) and `com.rayhanwibowo.jailbreakDetectionWithFirebase` (iOS; verify in Xcode). If changing them, update native identifiers before downloading configuration.
2. Download **your own** `google-services.json` into `android/app/google-services.json` and **your own** `GoogleService-Info.plist` into `ios/Runner/GoogleService-Info.plist`. The exact plist filename matters. No credentials/configuration from Merchant, BeepMobileApp, or VeeDrive are copied into this project.
3. Android applies Google Services and the Crashlytics Gradle plugin when its JSON exists. The iOS `Workshop Firebase` build phase copies an optional plist into the bundle and runs the Crashlytics symbol uploader. It supports CocoaPods and Flutter's Swift Package Manager integration. No placeholder native files are committed.
4. Open Crashlytics in the Firebase console and finish onboarding. In `.env`, set `FIREBASE_ENABLED=true`. Keep `APP_CHECK_DEBUG=true` for the first workshop run.
5. Run the app. In Firebase Console → App Check, register the app and add the debug token emitted in the **native device logs**. Restart and rerun the check. Treat the debug token as a credential; do not commit it, show it in screenshots, or use it in production. The app never displays or logs the acquired App Check JWT.
6. Check that the dashboard shows Firebase ready and a token acquired. This means acquisition worked; the API still needs to verify it. No backend URL is required for this stage.

For native symbol integration, Firebase recommends running `flutterfire configure` **after** adding Crashlytics. It can regenerate attendee-specific files and add an uploader build phase. This starter already supplies a native uploader; keep only one iOS upload phase if the CLI adds a second. The app intentionally uses `Firebase.initializeApp()` with native configuration, so importing generated `firebase_options.dart` is unnecessary for this Android/iOS module. Keep this repository's `firebase.json` functions entry if using the CLI.

### Real attestation

Set `APP_CHECK_DEBUG=false`. Register Play Integrity for Android and App Attest/DeviceCheck for Apple in App Check. Configure Android signing SHA-256 and Play Integrity/Play Console requirements for your distribution channel. Enable App Attest capability (`com.apple.developer.devicecheck.appattest-environment` = `production`) in the Runner target/signing profile when using App Attest. Run on physical devices; Apple uses App Attest with DeviceCheck fallback. The debug provider deliberately bypasses real integrity attestation and must not be presented as proof of device health.

For a release test build, use `APP_CHECK_DEBUG=false` and explicitly opt into `ENABLE_TEST_CONTROLS=true` only in a workshop build. For distribution, set test controls to `false`, use your own Android release signing, configure Apple signing/capabilities, and verify symbols in Crashlytics.

## Host the API on Firebase

An optional **Cloud Functions for Firebase (2nd gen)** backend is included in `functions/`. It verifies the header with Firebase Admin SDK, restricts accepted Firebase app IDs, validates the observation payload, applies server policy, and writes structured security events to Cloud Logging. Firebase project creation, billing activation, and deployment are attendee actions; nothing has been deployed by this repository.

Cloud Functions deployment requires a Firebase project on the Blaze plan, Firebase CLI, and Node.js 22. The following commands deploy to **your selected project** and can incur usage charges:

```sh
firebase login
cd functions
npm ci
npm test
cd ..
firebase deploy --only functions:workshopApi --project YOUR_FIREBASE_PROJECT_ID
```

At the CLI prompt, set `ALLOWED_APP_IDS` to the comma-separated **Firebase app IDs** for the registered Android/iOS apps (`1:…:android:…`, `1:…:ios:…`), not package or bundle IDs. The CLI saves parameters to its local functions env file, which is ignored. The sample fails closed when the list is empty or the token is from an unlisted app.

Copy the deployed function URL printed by the CLI into `.env`:

```json
"API_BASE_URL": "https://asia-southeast1-YOUR_PROJECT.cloudfunctions.net/workshopApi"
```

Use the actual CLI URL if it differs. The app appends `/integrity`, producing `POST <function URL>/integrity`. Rebuild the app and run a check. The function is publicly invokable at the network layer so the mobile client can reach it; its handler requires valid App Check. For a non-workshop API add user authentication/authorization, rate limits, and monitoring. `maxInstances: 2` limits instances but is not a billing cap.

The Functions emulator can exercise the handler with registered Firebase debug-provider tokens. This example intentionally requires HTTPS in the app, so use an HTTPS tunnel for a device-to-emulator exercise. It does not introduce a token verification bypass for emulation.

## Workshop exercises

| Exercise | Expected result |
| --- | --- |
| Default local mode | Local result; Firebase disabled; no server allow |
| Configure Firebase + registered debug provider, URL blank | Token acquired; API not configured |
| Configure deployed function + valid token | API returns allow or block according to its policy |
| Simulate jailbreak / root | Immediate block page and GIF; simulated non-fatal finding; observation still sent to API if configured |
| End simulation | Reruns the actual native check; does not bypass a genuine finding |
| Real rooted/jailbroken device | Local signals trigger block; test only on owned test devices |
| Invalid/unregistered token or offline App Check | Retry state; no API request without a token; no accusation of jailbreak |
| API offline, 401/403, malformed response, redirect | Access is not granted; retry state; existing local block persists |
| Log non-fatal error | Workshop error appears in Crashlytics after upload |
| Intentional native crash | Confirmation → process exits → reopen app → inspect fatal report |

For Crashlytics testing on iOS, launch once, stop/disconnect the debugger, and reopen the installed app from the device before crashing. Debuggers can intercept crashes. Reopen after the crash without reinstalling. Allow several minutes and a network connection for delivery. If reports are missing, check collection, Firebase app ID, upload build phase, and dSYM upload warnings. Readable obfuscated Dart reports additionally require Flutter symbol upload. Native collection defaults to disabled; the Dart setup enables it according to `CRASHLYTICS_ENABLED`. Firebase persists collection preferences between runs: to opt out after enabling it, run once with Firebase enabled and `CRASHLYTICS_ENABLED=false`.

## Modules and verification

```text
lib/config/                    Compile-time configuration and URL validation
lib/security/                  Native detector and Firebase/App Check setup
lib/telemetry/                 Best-effort Crashlytics reporting
lib/network/                   Dio interceptor and typed API decision
lib/features/workshop/         Controller and one dashboard/block screen
functions/                     Deployable Firebase API and policy tests
docs/                          API contract and presenter notes
```

```sh
flutter analyze
flutter test
node --test functions/test/policy.test.js
flutter build apk --debug
# On a configured Mac:
flutter build ios --simulator --debug
```

Tests use injected detectors/token providers and a fake HTTP adapter. They verify failure behavior and orchestration, not real attestation or plugin detection accuracy. Real-device validation and Firebase console delivery require your project and devices.

Read [the API contract](docs/API_CONTRACT.md) and [presenter notes](docs/WORKSHOP.md) before teaching this module.

## Security model and limitations

Local checks are useful signals and fast feedback, but a hooked client can falsify them. An HTTPS API must verify App Check and enforce policy **on every protected operation**; hiding a page or obtaining a one-time allow response cannot secure later requests. A cached valid token can also remain usable for its lifetime. App Check complements user authentication and authorization.

The sample policy rejects known local compromise, simulations, and inconclusive results after successful attestation. Its clean-local decision is intentionally a teaching baseline: if that client boolean is hooked to false, the server cannot recover the truth from the same boolean. Real protection needs independently verified attestation/risk signals and server-owned rules. App Check does not supply your backend with a universal “jailbroken” boolean.

Crashlytics receives observations and test findings as non-fatal reports, including simulation markers. It cannot reliably log **all jailbreak/root attempts**: hooks can disable reporting, offline reports may never upload, reports can be grouped/limited, and the app cannot observe every external attempt. Use server-side Cloud Logging/security monitoring as the audit trail for requests that reach your API. Logging/reporting failure never prevents the local block.

The implementation draws on security module patterns in locally available BeepMobileApp, VeeDrive, and veestore-merchant-app, with independent workshop configuration.

## Official references

- [Flutter App Check setup](https://firebase.google.com/docs/app-check/flutter/default-providers)
- [Debug providers](https://firebase.google.com/docs/app-check/flutter/debug-provider)
- [Verify App Check on your backend](https://firebase.google.com/docs/app-check/custom-resource-backend)
- [Flutter Crashlytics setup](https://firebase.google.com/docs/crashlytics/flutter/get-started)
- [Readable Flutter crash reports](https://firebase.google.com/docs/crashlytics/flutter/get-deobfuscated-reports)
- [Functions runtime and deployment options](https://firebase.google.com/docs/functions/manage-functions)
- [Local detection plugin setup and physical-device guidance](https://pub.dev/packages/jailbreak_root_detection)
# jailbreak-detection-with-firebase
