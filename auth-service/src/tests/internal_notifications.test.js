'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.KC_REALM         = 'kabutare-hospital';
process.env.KC_ADMIN_URL     = 'http://keycloak-test';
process.env.KC_CLIENT_ID     = 'auth-service-test';
process.env.KC_CLIENT_SECRET = 'test-secret';
process.env.INTERNAL_SECRET  = 'test-internal-secret';
process.env.BREVO_API_KEY    = 'env-brevo-key';
process.env.BREVO_SENDER_EMAIL = 'env@hospital.local';
process.env.BREVO_SENDER_NAME  = 'GMAO Test';

// ── Mock rate-limiter ─────────────────────────────────────────────────────────
jest.mock('express-rate-limit', () => () => (req, res, next) => next());

// ── Mock du template email (on ne teste pas le rendu HTML ici) ────────────────
jest.mock('../utils/email_service', () => ({
  sendEmail:         jest.fn().mockResolvedValue(undefined),
  buildEmailContent: jest.fn(() => ({ subject: 's', htmlContent: 'h', textContent: 't' })),
}));

const request          = require('supertest');
const { app, server }  = require('../index');
const { getDb }        = require('../database');

afterAll(() => server.close());

const HEADERS = { 'x-internal-secret': 'test-internal-secret' };

// =============================================================================
// POST /internal/notifications/send-email — filtrage par seuil d'urgence minimal
// =============================================================================
describe('Internal — send-email — seuil min_urgency_new_issue', () => {
  test('✅ seuil atteint (urgence == seuil) → email envoyé', async () => {
    const db = getDb();
    db.prepare(`
      INSERT INTO user_notification_preferences (user_id, notify_new_issue, min_urgency_new_issue, preferences_set)
      VALUES ('tech-seuil-atteint', 1, 'Urgent', 1)
    `).run();

    const res = await request(app)
      .post('/internal/notifications/send-email')
      .set(HEADERS)
      .send({
        type: 'critical_new_issue', to_email: 'tech@kabutare.rw', user_id: 'tech-seuil-atteint',
        payload: { urgency: 'Urgent' },
      });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ sent: true });
  });

  test('🚫 urgence < seuil → pas d\'email', async () => {
    const db = getDb();
    db.prepare(`
      INSERT INTO user_notification_preferences (user_id, notify_new_issue, min_urgency_new_issue, preferences_set)
      VALUES ('tech-seuil-non-atteint', 1, 'Critique', 1)
    `).run();

    const res = await request(app)
      .post('/internal/notifications/send-email')
      .set(HEADERS)
      .send({
        type: 'critical_new_issue', to_email: 'tech@kabutare.rw', user_id: 'tech-seuil-non-atteint',
        payload: { urgency: 'Urgent' },
      });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ sent: false, reason: 'below_urgency_threshold' });
  });

  test('✅ prefs == null + urgence Critique → comportement par défaut, email envoyé', async () => {
    const res = await request(app)
      .post('/internal/notifications/send-email')
      .set(HEADERS)
      .send({
        type: 'critical_new_issue', to_email: 'tech@kabutare.rw', user_id: 'tech-sans-prefs',
        payload: { urgency: 'Critique' },
      });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ sent: true });
  });

  test('🚫 prefs == null + urgence Faible → seuil par défaut Critique non atteint', async () => {
    const res = await request(app)
      .post('/internal/notifications/send-email')
      .set(HEADERS)
      .send({
        type: 'critical_new_issue', to_email: 'tech@kabutare.rw', user_id: 'tech-sans-prefs-2',
        payload: { urgency: 'Faible' },
      });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ sent: false, reason: 'below_urgency_threshold' });
  });
});
