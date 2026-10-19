# API contract

The Firebase function is `workshopApi`, hosted in `asia-southeast1`. `API_BASE_URL` is its deployed HTTPS URL. Dio appends the path below.

## Request

```http
POST /integrity
Content-Type: application/json
X-Firebase-AppCheck: <current Firebase App Check token>
```

```json
{
  "local": {
    "verdict": "clear",
    "signals": [],
    "simulated": false,
    "platform": "android"
  }
}
```

`verdict`: `clear`, `compromised`, or `inconclusive`. `platform`: `android` or `ios`. The sample validates signal names and limits the array to 20 items. No hardware IDs or JWTs are logged. App Check JWTs are acquired per request through Firebase SDK caching/renewal; the app does not persist or manually decode them.

The interceptor rejects a non-HTTPS/foreign origin, removes caller-supplied attestation headers, and prevents redirects from forwarding the token elsewhere. Token acquisition failure stops the request. It does not silently call an unprotected API.

## Evaluated decision: HTTP 200

```json
{ "allow": true, "reason": "attestation_verified_and_policy_passed" }
```

```json
{ "allow": false, "reason": "device_integrity_rejected" }
```

Block reasons also include `workshop_simulation` and `local_check_inconclusive`. The app requires a boolean `allow` and string `reason`. It preserves a prior local block even if the API says allow. An inconclusive local result is submitted to the API, where the example policy rejects it. The API can independently deny a locally clean device.

## Verification / protocol errors

| HTTP status | Body `error` | Meaning |
| --- | --- | --- |
| 400 | `invalid_local_evidence` | Payload fails schema validation |
| 401 | `app_check_missing` / `app_check_invalid` | No verified attestation |
| 403 | `app_id_rejected` | Valid token for a Firebase app outside the allowlist |
| 404 | `not_found` | Unknown route |
| 405 | `method_not_allowed` | Use POST |
| 503 | `server_not_configured` | No accepted Firebase app IDs configured |

The app treats HTTP errors, transport errors, redirects, and malformed decisions as unavailable verification. It shows retry and never converts those failures into allow or a jailbreak diagnosis.

## Add real protected operations

Apply `getAppCheck().verifyToken()` and app-ID restrictions at each protected route, then enforce server policy there. Add Firebase Authentication token verification independently for user identity, and authorization for the requested resource. Do not accept a client-provided previous `allow=true` or treat `local.verdict=clear` as independent evidence. Consider replay protection for sensitive operations; this starter uses normal App Check tokens and does not consume limited-use tokens.

Cloud Logging receives `app_check_missing`, `app_check_invalid`, `app_id_rejected`, and `integrity_decision` events. It only observes requests reaching the server; it is not a complete record of external jailbreak attempts. Add retention, quotas, access policy, and alerts appropriate to a real deployment.
