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

// ── Mock Keycloak Admin API (résolution des utilisateurs par rôle) ────────────
const mockKcAdminFetch = jest.fn();
jest.mock('../utils/keycloakAdmin', () => ({
  kcAdminFetch: (...args) => mockKcAdminFetch(...args),
}));

// ── Mock de l'appel de journalisation vers db-service (introduit par cette feature) ──
global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({}) });

const request          = require('supertest');
const { app, server }  = require('../index');
const { getDb }        = require('../database');
const { sendEmail }    = require('../utils/email_service');

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

// =============================================================================
// POST /internal/notifications/send-to-roles — type monthly_report
// =============================================================================
describe('Internal — send-to-roles — type monthly_report', () => {
  // Deux superviseurs Keycloak simulés pour tester l'opt-out individuel
  const KC_SUPERVISORS = [
    { id: 'sup-optin',  email: 'sup.optin@kabutare.rw',  firstName: 'Alice', lastName: 'OptIn' },
    { id: 'sup-optout', email: 'sup.optout@kabutare.rw', firstName: 'Bob',   lastName: 'OptOut' },
  ];

  const kcOk = (data) => Promise.resolve({
    ok:   true,
    json: () => Promise.resolve(data),
  });

  // Laisse le setImmediate + les await internes de send-to-roles se terminer
  const flushAsync = () => new Promise((resolve) => setTimeout(resolve, 30));

  beforeEach(() => {
    sendEmail.mockClear();
    mockKcAdminFetch.mockReset();
  });

  test('✅ type monthly_report reconnu → 200 {queued:true} (plus de 400)', async () => {
    mockKcAdminFetch.mockImplementation(() => kcOk([]));

    const res = await request(app)
      .post('/internal/notifications/send-to-roles')
      .set(HEADERS)
      .send({
        type:    'monthly_report',
        roles:   ['supervisor', 'admin'],
        payload: { month_label: 'juin 2026', issues_created: 42 },
      });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ queued: true });
    await flushAsync();
  });

  test('✅ opt-out individuel : notify_monthly_report = 0 → un seul envoi tenté', async () => {
    const db = getDb();
    // Bob a désactivé le rapport mensuel, Alice n'a pas de préférences (opt-in par défaut)
    db.prepare(`
      INSERT OR REPLACE INTO user_notification_preferences (user_id, notify_monthly_report, preferences_set)
      VALUES ('sup-optout', 0, 1)
    `).run();

    mockKcAdminFetch.mockImplementation((path) =>
      path.includes('/roles/supervisor/') ? kcOk(KC_SUPERVISORS) : kcOk([])
    );

    const res = await request(app)
      .post('/internal/notifications/send-to-roles')
      .set(HEADERS)
      .send({
        type:    'monthly_report',
        roles:   ['supervisor'],
        payload: { month_label: 'juin 2026' },
      });

    expect(res.status).toBe(200);
    await flushAsync();

    // Un seul email tenté : celui d'Alice (opt-in)
    expect(sendEmail).toHaveBeenCalledTimes(1);
    expect(sendEmail).toHaveBeenCalledWith(
      expect.objectContaining({ to: 'sup.optin@kabutare.rw' })
    );
  });

  test('🚫 non-régression : un type réellement inconnu répond toujours 400', async () => {
    const res = await request(app)
      .post('/internal/notifications/send-to-roles')
      .set(HEADERS)
      .send({ type: 'type_inconnu_xyz', roles: ['supervisor'], payload: {} });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/inconnu/i);
  });
});
