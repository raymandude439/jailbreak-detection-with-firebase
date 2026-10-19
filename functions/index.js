'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getAppCheck } = require('firebase-admin/app-check');
const { onRequest } = require('firebase-functions/v2/https');
const { defineString } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const { createHandler } = require('./policy');
initializeApp();
const allowedApps = defineString('ALLOWED_APP_IDS', {
  description: 'Comma-separated Firebase app IDs for the workshop Android/iOS apps (not package names).',
});
exports.workshopApi = onRequest({ region: 'asia-southeast1', maxInstances: 2, timeoutSeconds: 30, cors: false }, (req, res) => {
  return createHandler({
    verifyToken: (token) => getAppCheck().verifyToken(token),
    allowedAppIds: allowedApps.value().split(',').map((id) => id.trim()).filter(Boolean),
    audit: (event) => logger.info('workshop_security', event),
  })(req, res);
});
