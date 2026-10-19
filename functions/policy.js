'use strict';

const signals = new Set([
  'jailbreak', 'notRealDevice', 'proxied', 'debugged', 'devMode',
  'reverseEngineered', 'fridaFound', 'cydiaFound', 'tampered',
  'onExternalStorage', 'unknown', 'probe_unavailable', 'unsupported_platform',
  'simulated_root', 'simulated_jailbreak',
]);

function validLocal(local) {
  return local && ['clear', 'compromised', 'inconclusive'].includes(local.verdict)
    && typeof local.simulated === 'boolean'
    && ['android', 'ios'].includes(local.platform)
    && Array.isArray(local.signals) && local.signals.length <= 20
    && local.signals.every((signal) => signals.has(signal));
}

function decide(local) {
  // Client evidence is advisory and can be falsified. Verification happens
  // before this policy. Add independent risk signals here for production.
  if (local.simulated) return { allow: false, reason: 'workshop_simulation' };
  if (local.verdict === 'compromised'
      || local.signals.some((s) => ['jailbreak', 'fridaFound', 'cydiaFound'].includes(s))) {
    return { allow: false, reason: 'device_integrity_rejected' };
  }
  if (local.verdict !== 'clear') return { allow: false, reason: 'local_check_inconclusive' };
  return { allow: true, reason: 'attestation_verified_and_policy_passed' };
}

function createHandler({ verifyToken, allowedAppIds, audit }) {
  return async (req, res) => {
    res.set('Cache-Control', 'no-store');
    // onRequest preserves the suffix after the function name.
    if (req.path !== '/integrity') return res.status(404).json({ error: 'not_found' });
    if (req.method !== 'POST') return res.status(405).set('Allow', 'POST').json({ error: 'method_not_allowed' });
    // No JWTs, raw bodies, device IDs or auth tokens are written to logs.
    const token = req.get('X-Firebase-AppCheck');
    if (!token) {
      audit({ event: 'app_check_missing' });
      return res.status(401).json({ error: 'app_check_missing' });
    }
    let claims;
    try { claims = await verifyToken(token); }
    catch (_) {
      audit({ event: 'app_check_invalid' });
      return res.status(401).json({ error: 'app_check_invalid' });
    }
    if (!allowedAppIds.length) return res.status(503).json({ error: 'server_not_configured' });
    if (!allowedAppIds.includes(claims.app_id)) {
      audit({ event: 'app_id_rejected' });
      return res.status(403).json({ error: 'app_id_rejected' });
    }
    if (!validLocal(req.body?.local)) return res.status(400).json({ error: 'invalid_local_evidence' });
    const decision = decide(req.body.local);
    audit({ event: 'integrity_decision', appId: claims.app_id,
      verdict: req.body.local.verdict, simulated: req.body.local.simulated,
      allow: decision.allow, reason: decision.reason });
    // Both allow/block are successful evaluations. 401/403 are verification errors.
    return res.status(200).json(decision);
  };
}
module.exports = { validLocal, decide, createHandler };
