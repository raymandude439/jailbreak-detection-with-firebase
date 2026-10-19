const { test } = require('node:test');
const assert = require('node:assert/strict');
const { decide, createHandler } = require('../policy');
const clean = { verdict: 'clear', signals: [], simulated: false, platform: 'android' };

test('policy blocks compromised, unknown, inconsistent and simulated evidence', () => {
  assert.equal(decide(clean).allow, true);
  assert.equal(decide({ ...clean, verdict: 'compromised' }).allow, false);
  assert.equal(decide({ ...clean, verdict: 'inconclusive' }).allow, false);
  assert.equal(decide({ ...clean, signals: ['fridaFound'] }).allow, false);
  assert.equal(decide({ ...clean, simulated: true }).allow, false);
});

async function request({ token = 'test-token', verify = async () => ({ app_id: 'app' }), body = { local: clean }, apps = ['app'] } = {}) {
  const result = { code: 200, body: null, logs: [] };
  const res = { set() { return this; }, status(code) { result.code = code; return this; }, json(body) { result.body = body; return this; } };
  const handler = createHandler({ verifyToken: verify, allowedAppIds: apps, audit: (entry) => result.logs.push(entry) });
  await handler({ path: '/integrity', method: 'POST', get: () => token, body }, res);
  return result;
}
test('missing or forged tokens never reach an allow decision', async () => {
  assert.equal((await request({ token: '' })).code, 401);
  assert.equal((await request({ verify: async () => { throw Error('invalid'); } })).code, 401);
});
test('token must belong to configured Firebase app', async () => {
  assert.equal((await request({ apps: ['different-app'] })).code, 403);
  assert.equal((await request({ apps: [] })).code, 503);
});
test('valid verified request allows; malformed evidence is rejected', async () => {
  assert.deepEqual((await request()).body, { allow: true, reason: 'attestation_verified_and_policy_passed' });
  assert.equal((await request({ body: { local: { ...clean, simulated: 'false' } } })).code, 400);
  assert.equal((await request({ body: { local: { ...clean, signals: ['untrusted arbitrary log data'] } } })).code, 400);
});
test('blocked decisions and invalid attestation are audited without tokens', async () => {
  const result = await request({ body: { local: { ...clean, verdict: 'compromised' } } });
  assert.equal(result.body.allow, false);
  assert.equal(result.logs[0].event, 'integrity_decision');
  assert.equal(JSON.stringify(result.logs).includes('test-token'), false);
});
