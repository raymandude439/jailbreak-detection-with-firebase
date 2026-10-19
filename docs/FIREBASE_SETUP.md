# Firebase setup: instructor and attendee guide

Use this guide in order. Each module has a stopping point, so the workshop can run with or without a deployed API or real platform attestation. Console labels may move; use the named product if the sidebar differs.

## Choose the workshop scope

| Module | What you configure | Complete when |
| --- | --- | --- |
| 0. Local demo | Nothing in Firebase | Simulations open the block screen |
| 1. Firebase project | Project + native app registration + downloaded files | Dashboard says Firebase ready |
| 2. Debug App Check | Register each device/install's debug secret | Dashboard acquires a token |
| 3. Crashlytics | Console onboarding + test reports | Non-fatal and fatal reports arrive |
| 4. API on Firebase | Blaze billing + Cloud Function + allowed app IDs | App receives a server decision |
| 5. Real attestation | Play Integrity / App Attest and DeviceCheck | Physical-device requests pass using real providers |

Modules 1–3 form the core Firebase workshop. Module 4 completes the API flow. Module 5 is an advanced session: prepare its platform accounts and signing before the event. No Firestore, Realtime Database, Storage, Firebase Hosting site, or Authentication provider is needed by this sample. Analytics is optional; this app uses explicit Crashlytics logs and does not include the Analytics SDK.

## Instructor preparation

Use a dedicated workshop Firebase project, separate from production. Decide whether attendees use their own projects or your shared workshop project.

| Arrangement | Preparation |
| --- | --- |
| Each attendee owns a project | Each registers their native app(s), debug tokens, and optionally deploys their own function. Each API deployment needs its own billing setup. |
| Instructor hosts one shared project | Register the starter Android/iOS apps once, distribute that project's native configuration privately, and register each attendee's debug token. Deploy the API once. Attendees can follow along without deployment access; give console access only to people who need it. |

**Keep the native configuration, App Check registration, and API in the same Firebase project.** A backend initialized in your instructor project will not accept an attendee's different-project App Check token by default. The sample app-ID allowlist is an additional restriction, not a cross-project trust mechanism.

Before the event, complete modules 1–4 yourself and confirm reports on a physical device. For a shared project, prepare a process for registering attendee tokens without projecting their secrets. Do not distribute service-account private keys or Apple private keys.

## Project-values worksheet

Fill this locally using Firebase Console → Project settings → General → Your apps. Replace the example identifiers if you change the native app IDs.

| Value | Where to find it / current starter value |
| --- | --- |
| Firebase project ID | Project settings; used by `firebase deploy --project` |
| Android package name | `com.rayhanwibowo.jailbreak_detection_with_firebase` |
| iOS bundle ID | `com.rayhanwibowo.jailbreakDetectionWithFirebase` |
| Android Firebase App ID | Your Android app details; looks like `1:…:android:…` |
| iOS Firebase App ID | Your Apple app details; looks like `1:…:ios:…` |
| API region | `asia-southeast1` in this sample |
| API base URL | Function URL printed after deployment; leave blank until module 4 |
| Android signing SHA-256 | Signing report for the exact build being tested; needed for real Play Integrity |
| Apple Team ID | Apple Developer membership; needed for real Apple provider setup |

A **Firebase App ID**, an Android package name, an iOS bundle ID, and a Firebase project ID are different identifiers. `ALLOWED_APP_IDS` takes Firebase App IDs only. Keep debug secrets out of this worksheet.

## Module 0 — Run local detection

From the project root:

```sh
flutter pub get
cp .env.example .env
flutter run --dart-define-from-file=.env
```

Keep `FIREBASE_ENABLED=false` and `API_BASE_URL` blank. Try **Simulate jailbreak**, end the simulation, then **Simulate root**. These controls exercise the reporting/block flow without modifying the device. Use a physical device to evaluate actual detection; emulator results are not proof of real root or jailbreak.

**Acceptance:** the block screen and Rick Astley GIF or its offline fallback appear. There is no Firebase token or server approval in this module.

## Module 1 — Create the project and register native apps

1. Open the [Firebase console](https://console.firebase.google.com/) and create a workshop project. Choose its project ID deliberately; record it in the worksheet. Analytics can remain disabled for this sample.
2. In Project settings → General → Your apps, add an Android app using the package name above. Download `google-services.json` and put it at `android/app/google-services.json`.
3. If teaching iOS, add an Apple app using the bundle ID above. Download `GoogleService-Info.plist` and put it at `ios/Runner/GoogleService-Info.plist`. Preserve the exact filename, including its hyphen and capitalization.
4. Record each Firebase App ID. One platform is enough if you are teaching only Android or only iOS.
5. In the root `.env`, change these values, preserving valid JSON:

```json
{
  "FIREBASE_ENABLED": "true",
  "APP_CHECK_DEBUG": "true",
  "CRASHLYTICS_ENABLED": "true",
  "ENABLE_TEST_CONTROLS": "true",
  "API_BASE_URL": "",
  "RICK_ASTLEY_GIF_URL": "https://media.giphy.com/media/Vuw9m5wXviFIQ/giphy.gif"
}
```

6. Fully stop the app and rebuild with `flutter run --dart-define-from-file=.env`. Hot reload does not apply new native files or compile-time configuration.

**Acceptance:** Firebase initializes. Token acquisition may fail until module 2; that is expected.

The native files are ignored by version control. This starter already wires the Android Google Services/Crashlytics plugins and the iOS plist copy/symbol-upload script. You do not need to manually add the plist to Xcode's Copy Bundle Resources: the script copies it. The app initializes from native files rather than importing generated Dart Firebase options. See the [Firebase Flutter setup guide](https://firebase.google.com/docs/flutter/setup) for the general CLI workflow; if you use `flutterfire configure`, preserve this repository's Functions configuration and avoid duplicate iOS upload phases.

## Module 2 — Register debug App Check tokens

Keep `APP_CHECK_DEBUG=true` and use a debug build. In Firebase Console → App Check → Apps, locate the registered native app. Configure its provider registration if the console requests it, then open its overflow menu → Manage debug tokens. Provider credentials/signing for real attestation are handled separately in module 5.

Run the app and let its initial security check request a token. Obtain the debug secret from native logs:

| Platform | Where to look |
| --- | --- |
| Android | Android Studio Logcat; filter for `DebugAppCheckProvider` |
| iOS | Open `ios/Runner.xcworkspace` in Xcode. Scheme → Run → Arguments: add `-FIRDebugEnabled`. Launch and inspect the Xcode console for the App Check debug token. |

Register that value under the correct Firebase app with a useful label such as `attendee-01-android`. Restart the app and rerun the check. Repeat for every installation that generates a different secret, including separate Android and iOS installations.

**Acceptance:** the App Check step reports token acquisition; the API step remains not configured. A registered debug secret allows test devices to bypass real attestation. Keep it private, revoke it if exposed, and never ship the debug provider. The debug secret is different from the short-lived App Check JWT sent to the API. [Official debug-provider instructions](https://firebase.google.com/docs/app-check/flutter/debug-provider).

## Module 3 — Enable and verify Crashlytics

1. Open Firebase Console → Crashlytics, select the correct app, and finish its onboarding. The Flutter SDK and error handlers are already integrated.
2. Confirm `.env` has Firebase and Crashlytics enabled. Rebuild. The dashboard should show Crashlytics enabled.
3. Tap **Log non-fatal error**. Run a jailbreak/root simulation too, so you can inspect a finding marked `simulated=true`.
4. Tap **Intentional native crash** and confirm. Reopen the installed app without reinstalling it, and allow time online for upload.
5. For iOS, stop/disconnect the debugger and launch the installed app from its icon before triggering the crash. A debugger can intercept it.

**Acceptance:** Crashlytics shows `workshop_intentional_non_fatal`, a simulation finding, and a fatal test crash for the intended app/version. Inspect the report's logs/information to distinguish simulation from a native finding. Delivery can take several minutes. If native stacks lack symbols, inspect the build's uploader/dSYM warnings; obfuscated Dart builds need Flutter symbol upload as well. [Official Crashlytics setup and test guidance](https://firebase.google.com/docs/crashlytics/flutter/get-started).

Collection defaults off natively; the app enables it from configuration. Its preference persists across launches. To disable collection after using it, run once with `FIREBASE_ENABLED=true` and `CRASHLYTICS_ENABLED=false`.

## Module 4 — Deploy the API to Firebase

**Project setup:** upgrade this workshop project to Blaze and attach a billing account. Set a budget alert appropriate to the event; alerts are not a hard spending cap. Use an account authorized to deploy Functions and enable required services. The Firebase CLI may request initial Google Cloud API enablement during deployment. Follow your organization's IAM process if access is restricted. Cloud Functions deployment requires Blaze. [Functions deployment prerequisites](https://firebase.google.com/docs/functions/get-started).

**Local setup:** install Node.js 22 and Firebase CLI on the instructor's or deploying attendee's computer. From the project root:

```sh
npm install -g firebase-tools
firebase login
firebase projects:list
cd functions
npm ci
npm test
cd ..
```

The repository already has `firebase.json` and `functions/`; there is no need to run `firebase init` over them.

Copy `functions/.env.example` to `functions/.env`. Replace its placeholder with your Android and/or iOS Firebase App IDs, separated by commas. With one platform, supply one ID:

```dotenv
ALLOWED_APP_IDS=YOUR_ANDROID_FIREBASE_APP_ID,YOUR_IOS_FIREBASE_APP_ID
```

This is a **server dotenv file**. The root `.env` is **Flutter JSON**. Do not interchange the formats. Keep `.env` values local; example files contain no usable project credentials.

Deploy to the project recorded in your worksheet:

```sh
firebase deploy --only functions:workshopApi --project YOUR_FIREBASE_PROJECT_ID
```

Deployment runs backend tests and creates a second-generation HTTP function in `asia-southeast1`. If `ALLOWED_APP_IDS` was not provided in the env file, the CLI prompts for it. The runtime uses its Firebase/Google Cloud identity; downloading a service-account JSON key into the app or repo is unnecessary.

Set the root Flutter `.env` `API_BASE_URL` to the deployed **function URL**, without `/integrity`, for example:

```json
"API_BASE_URL": "https://asia-southeast1-YOUR_PROJECT.cloudfunctions.net/workshopApi"
```

Use the actual deployment output if its URL differs. Rebuild and run the check. Dio appends `/integrity` and supplies `X-Firebase-AppCheck`. A clean local result can be allowed; compromise, simulations, and inconclusive observations are rejected by the sample server policy. Emulator detections can therefore produce a block even with a valid debug token.

**Acceptance:** the app shows a server decision, and Cloud Logging shows an `integrity_decision` event. In Google Cloud Logs Explorer, select the same project and filter:

```text
resource.type="cloud_run_revision"
jsonPayload.event="integrity_decision"
```

If needed, narrow by the function's Cloud Run service and deployment time. Check a simulation yields `allow=false` and `simulated=true`.

**Enforcement distinction:** this is an HTTP `onRequest` function, using explicit Admin SDK `verifyToken()` in its handler. App Check verification is active on this route regardless of console enforcement toggles for other Firebase services. It is not an `onCall` callable using automatic enforcement. Hosting need not be enabled. [Custom-backend verification](https://firebase.google.com/docs/app-check/custom-resource-backend).

## Module 5 — Switch to real attestation (advanced)

Complete the relevant platform branch before setting `APP_CHECK_DEBUG=false`. Keep module 2 available as the fallback teaching path if platform-account provisioning is not ready.

### Android: Play Integrity

1. Prepare a Play Console app and link its Play Integrity API to the same Firebase/Google Cloud project. Linking requires the appropriate project ownership.
2. Find the exact signing certificate's SHA-256. For local builds, run `./gradlew signingReport` from `android/`. For Play-distributed builds, use the Play app-signing certificate from Play Console; an upload certificate may differ.
3. Register Play Integrity for the Android app in Firebase App Check with that SHA-256.
4. Match App Check's recognition/licensing/device-integrity settings to your distribution channel. In particular, a directly installed APK cannot satisfy Play recognition requirements intended for Play-published builds. Use Firebase's distribution settings table rather than weakening settings blindly.
5. Set `APP_CHECK_DEBUG=false`, rebuild, and verify acquisition plus an API decision on a physical device.

[Play Integrity setup and distribution settings](https://firebase.google.com/docs/app-check/android/play-integrity-provider).

### iOS: App Attest with DeviceCheck fallback

1. Prepare an Apple Developer team and a correctly signed app matching the registered bundle ID. Register App Attest for that Apple app in Firebase App Check.
2. In Xcode, add the App Attest capability to Runner and use a provisioning profile that includes it. Set `com.apple.developer.devicecheck.appattest-environment` to `production`; Firebase does not accept App Attest sandbox tokens. This is an attestation environment setting, not a requirement to publish the workshop app to the App Store. [App Attest setup](https://firebase.google.com/docs/app-check/ios/app-attest-provider).
3. Because this app uses DeviceCheck fallback, configure DeviceCheck too: create a DeviceCheck private key in the Apple Developer portal and register it with Firebase App Check using the console's requested key/team details. Upload the private key only to the provider configuration, never the Flutter app or repository. [DeviceCheck setup](https://firebase.google.com/docs/app-check/ios/devicecheck-provider).
4. Set `APP_CHECK_DEBUG=false`, rebuild, and verify on a physical iPhone. Simulators use the debug module.

**Acceptance:** the dashboard identifies the real providers, acquires a token, and receives an API decision. Explain that App Check supplies attestation, not a universal “device is not jailbroken” guarantee. Disable `ENABLE_TEST_CONTROLS` before distributing a non-workshop build.

## Troubleshooting checkpoints

| Symptom | Check |
| --- | --- |
| Firebase unavailable | Correct native file path, correct package/bundle registration, valid downloaded file, full rebuild |
| App Check unavailable in debug mode | Secret registered under this app/project, correct debug flag, native logs, internet; retry after registration |
| No iOS debug secret in logs | Xcode launch argument `-FIRDebugEnabled`, native console, initial check actually requested a token |
| API returns 401 | Header present and current; client and function belong to the same Firebase project |
| API returns 403 | Firebase App ID is included in `ALLOWED_APP_IDS`; also check deployment/platform invocation restrictions if the handler was never reached |
| API returns 503 `server_not_configured` | Nonempty server app-ID list and a redeployment after changing it |
| API returns 404 | Base URL points to `workshopApi`; app appends `/integrity` once |
| API returns block on emulator | Inspect local verdict/signals; debug App Check does not change the local detector or server policy |
| Real Android provider fails | Signing SHA-256, Play project linkage, recognition/licensing settings, and distribution path |
| Real Apple provider fails | Team/bundle/signing profile, production App Attest entitlement, DeviceCheck fallback registration |
| Crashlytics report absent | Collection enabled, correct app, reopen after crash, device online, debugger detached, allow upload time |
| Missing native crash symbols | Build phase/plugin configured, successful dSYM upload; avoid duplicate upload scripts |

## End-of-workshop handover

- [ ] Project ID, native Firebase App IDs, and deployed URL are recorded locally.
- [ ] Another attendee can follow the same modules with their own Firebase files.
- [ ] Debug-token registration and real attestation are explained as separate modes.
- [ ] One non-fatal, one simulation finding, and one fatal test report are verified.
- [ ] The API verifies App Check before evaluating client observations.
- [ ] The instructor can explain how a Frida hook can still falsify local evidence.
- [ ] Unneeded shared debug tokens are revoked after the workshop.
- [ ] If the demo API is no longer needed, the project owner removes it with `firebase functions:delete workshopApi --region asia-southeast1 --project YOUR_FIREBASE_PROJECT_ID` and reviews remaining cloud resources and billing.

For teaching exercises and the security explanation, continue with [presenter notes](WORKSHOP.md). For exact payloads and errors, use the [API contract](API_CONTRACT.md).
