'use strict';

// ── Tests du rapport KPI mensuel (jobs/monthly_report_job.js) ─────────────────
// Sémantique vérifiée :
//   - mois vide → zéros et mttr_hours = null (jamais NaN ni division par zéro) ;
//   - incident créé au mois M et résolu au mois M+1 → compté dans le MTTR de M+1 ;
//   - resolved_at NULL toujours exclu du MTTR ;
//   - l'envoi passe par POST /internal/notifications/send-to-roles (type
//     monthly_report) et le déclenchement est audité via logAction.

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

// ── Mock du logger (pas d'appels HTTP en test) ────────────────────────────────
jest.mock('../utils/logger', () => ({
  logAction:      jest.fn(),
  extractReqMeta: jest.fn(() => ({})),
  sendLog:        jest.fn(),
}));

// ── Mock axios (l'envoi vers auth-service est vérifié, jamais exécuté) ────────
jest.mock('axios', () => ({
  post: jest.fn().mockResolvedValue({ data: { queued: true } }),
}));

const axios = require('axios');
const { getDb, closeDb } = require('../database');
const { logAction } = require('../utils/logger');
const {
  computeMonthlyKpis, sendMonthlyReport, previousMonth, monthLabel,
} = require('../jobs/monthly_report_job');

let db;

beforeAll(() => {
  db = getDb();

  db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, status)
    VALUES ('eq-kpi-1', 'Concentrateur O2 test', 'OPD', 'Monitoring', 'Out of service')
  `).run();

  const insertIssue = db.prepare(`
    INSERT INTO issues (
      id, equipment_id, equipment_name, department, type, description,
      reporter, urgency, status, created_at, resolved_at
    ) VALUES (?, ?, ?, 'OPD', 'Panne', 'Incident KPI test', 'Dr. Test', ?, ?, ?, ?)
  `);

  // Créé et résolu en mai 2026 (48 h) → MTTR de mai
  insertIssue.run('iss-kpi-a', 'eq-kpi-1', 'Concentrateur O2 test', 'Critique',
    'Completed', '2026-05-10 08:00:00', '2026-05-12 08:00:00');
  // Créé en mai, résolu en juin (312 h) → MTTR de JUIN uniquement
  insertIssue.run('iss-kpi-b', 'eq-kpi-1', 'Concentrateur O2 test', 'Urgent',
    'Completed', '2026-05-20 08:00:00', '2026-06-02 08:00:00');
  // Créé en mai, jamais résolu → exclu du MTTR, encore ouvert
  insertIssue.run('iss-kpi-c', null, null, 'Moyen',
    'Reported', '2026-05-25 08:00:00', null);
});

afterAll(() => {
  closeDb();
});

describe('computeMonthlyKpis — sémantique mensuelle', () => {
  test('✅ mois vide → zéros et mttr_hours = null', () => {
    const kpis = computeMonthlyKpis('2026-04');

    expect(kpis.issues_created).toBe(0);
    expect(kpis.issues_resolved).toBe(0);
    expect(kpis.mttr_hours).toBeNull();
    expect(kpis.by_urgency).toEqual({});
    expect(kpis.top_equipment).toEqual([]);
    expect(kpis.month_label).toBe('avril 2026');
  });

  test('✅ mai 2026 : 3 créés, 1 résolu, MTTR = 48 h (b et c exclus)', () => {
    const kpis = computeMonthlyKpis('2026-05');

    expect(kpis.issues_created).toBe(3);
    expect(kpis.issues_resolved).toBe(1);          // seul iss-kpi-a est résolu EN mai
    expect(kpis.mttr_hours).toBe(48);              // iss-kpi-b (résolu en juin) et c (NULL) exclus
    expect(kpis.issues_still_open).toBe(2);        // b (résolu après fin mai) + c (jamais résolu)
    expect(kpis.by_urgency).toEqual({ Critique: 1, Urgent: 1, Moyen: 1 });
    expect(kpis.top_equipment).toEqual([{ name: 'Concentrateur O2 test', count: 2 }]);
    expect(kpis.equipment_out_of_service).toBe(1);
  });

  test('✅ incident créé M / résolu M+1 → compté dans le MTTR de juin', () => {
    const kpis = computeMonthlyKpis('2026-06');

    expect(kpis.issues_created).toBe(0);           // rien créé en juin
    expect(kpis.issues_resolved).toBe(1);          // iss-kpi-b résolu le 02/06
    expect(kpis.mttr_hours).toBe(312);             // 13 jours entre création (mai) et résolution (juin)
    expect(kpis.issues_still_open).toBe(1);        // seul iss-kpi-c reste ouvert fin juin
  });
});

describe('sendMonthlyReport — déclenchement de l\'envoi', () => {
  beforeEach(() => {
    axios.post.mockClear();
    logAction.mockClear();
  });

  test('✅ POST send-to-roles avec type monthly_report vers supervisor + admin', async () => {
    const payload = await sendMonthlyReport('2026-05');

    expect(axios.post).toHaveBeenCalledTimes(1);
    const [url, body, opts] = axios.post.mock.calls[0];
    expect(url).toBe('http://auth-service-test:3001/internal/notifications/send-to-roles');
    expect(body.type).toBe('monthly_report');
    expect(body.roles).toEqual(['supervisor', 'admin']);
    expect(body.payload.month_label).toBe('mai 2026');
    expect(opts.headers['x-internal-secret']).toBe('test-internal-secret');

    expect(payload.issues_created).toBe(3);
  });

  test('✅ le déclenchement est audité (logAction send_monthly_report)', async () => {
    await sendMonthlyReport('2026-05');

    expect(logAction).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'send_monthly_report', target_id: '2026-05' })
    );
  });
});

describe('Helpers de date', () => {
  test('✅ previousMonth : bascule d\'année correcte', () => {
    expect(previousMonth(new Date(2026, 0, 15))).toBe('2025-12'); // janvier → décembre N-1
    expect(previousMonth(new Date(2026, 6, 4))).toBe('2026-06');  // juillet → juin
  });

  test('✅ monthLabel en français', () => {
    expect(monthLabel('2026-06')).toBe('juin 2026');
    expect(monthLabel('2025-12')).toBe('décembre 2025');
  });
});
