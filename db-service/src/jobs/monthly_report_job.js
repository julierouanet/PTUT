// ── Rapport KPI mensuel par email (superviseurs + admins) ─────────────────────
// Calcule les KPIs GMAO du mois civil écoulé sur hospital.db puis délègue
// l'envoi à auth-service (POST /internal/notifications/send-to-roles, type
// monthly_report). Les préférences individuelles (opt-out notify_monthly_report)
// sont filtrées côté auth-service — jamais lues depuis db-service.
//
// Limitation assumée : pas de file d'attente ni de retry — si Keycloak ou
// Brevo est indisponible au moment du cron, le rapport du mois est perdu
// (l'échec est loggé, le service ne tombe jamais).

const axios = require('axios');
const cron  = require('node-cron');
const { getDb } = require('../database');
const { logAction } = require('../utils/logger');
const { AUTH_SERVICE_URL, INTERNAL_SECRET } = require('../config');

// Rôles destinataires du rapport mensuel
const REPORT_ROLES = ['supervisor', 'admin'];

// Libellés de mois en français pour le month_label de l'email
const MONTHS_FR = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/** Retourne le mois civil précédent au format 'YYYY-MM'. */
function previousMonth(now = new Date()) {
  const d = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

/** 'YYYY-MM' → 'juin 2026'. */
function monthLabel(month) {
  const [year, m] = month.split('-').map(Number);
  return `${MONTHS_FR[m - 1]} ${year}`;
}

/**
 * Calcule les KPIs GMAO du mois donné ('YYYY-MM') sur hospital.db.
 * Sémantique (cf. spec) :
 *   - issues_created  : created_at dans le mois ;
 *   - issues_resolved : resolved_at dans le mois (posé à la transition → Completed) ;
 *   - issues_still_open : créés avant la fin du mois ET non résolus à la fin du mois ;
 *   - mttr_hours : moyenne (resolved_at − created_at) des incidents RÉSOLUS dans le
 *     mois uniquement (un incident créé en M et résolu en M+1 compte dans le MTTR
 *     de M+1) ; resolved_at NULL toujours exclu ; aucun incident résolu → null ;
 *   - pm_compliance_pct / equipment_out_of_service : instantanés au moment du
 *     calcul (le cron tourne le 1er du mois à 06h00, soit ≈ fin du mois couvert).
 * @param {string} month - 'YYYY-MM'
 * @returns {object} payload prêt pour le template email monthly_report
 */
function computeMonthlyKpis(month) {
  const db    = getDb();
  const start = `${month}-01`;

  // Borne réutilisée : [date(start) ; date(start, '+1 month')[
  const inMonth = (col) => `date(${col}) >= date(?) AND date(${col}) < date(?, '+1 month')`;

  const issuesCreated = db.prepare(
    `SELECT COUNT(*) AS c FROM issues WHERE ${inMonth('created_at')}`
  ).get(start, start).c;

  const issuesResolved = db.prepare(
    `SELECT COUNT(*) AS c FROM issues WHERE resolved_at IS NOT NULL AND ${inMonth('resolved_at')}`
  ).get(start, start).c;

  const issuesStillOpen = db.prepare(`
    SELECT COUNT(*) AS c FROM issues
    WHERE date(created_at) < date(?, '+1 month')
      AND (resolved_at IS NULL OR date(resolved_at) >= date(?, '+1 month'))
  `).get(start, start).c;

  // MTTR en heures — AVG retourne NULL si aucun incident résolu dans le mois
  const mttrHours = db.prepare(`
    SELECT ROUND(AVG((julianday(resolved_at) - julianday(created_at)) * 24.0), 1) AS mttr
    FROM issues
    WHERE resolved_at IS NOT NULL AND ${inMonth('resolved_at')}
  `).get(start, start).mttr;

  // Répartition par urgence des incidents créés dans le mois
  const byUrgency = {};
  for (const row of db.prepare(
    `SELECT urgency, COUNT(*) AS n FROM issues WHERE ${inMonth('created_at')} GROUP BY urgency`
  ).all(start, start)) {
    byUrgency[row.urgency || 'Non renseigné'] = row.n;
  }

  // Conformité PM (adapté d'audit/tools/kpi_queries.js) — NULL si aucun plan
  const pmCompliancePct = db.prepare(`
    SELECT ROUND(100.0 * SUM(
      last_completed_date IS NOT NULL AND
      date(last_completed_date, '+' || frequency_months || ' months') >= date('now')
    ) / COUNT(*), 0) AS pct
    FROM preventive_maintenance_plans
  `).get().pct;

  const equipmentOutOfService = db.prepare(
    "SELECT COUNT(*) AS c FROM equipment WHERE status = 'Out of service'"
  ).get().c;

  // Top 3 des équipements par incidents créés dans le mois
  const topEquipment = db.prepare(`
    SELECT COALESCE(equipment_name, equipment_id) AS name, COUNT(*) AS count
    FROM issues
    WHERE ${inMonth('created_at')}
      AND (equipment_id IS NOT NULL OR equipment_name IS NOT NULL)
    GROUP BY COALESCE(equipment_name, equipment_id)
    ORDER BY count DESC, name ASC
    LIMIT 3
  `).all(start, start);

  return {
    month_label:              monthLabel(month),
    issues_created:           issuesCreated,
    issues_resolved:          issuesResolved,
    issues_still_open:        issuesStillOpen,
    by_urgency:               byUrgency,
    mttr_hours:               mttrHours,
    pm_compliance_pct:        pmCompliancePct,
    equipment_out_of_service: equipmentOutOfService,
    top_equipment:            topEquipment,
  };
}

/**
 * Calcule les KPIs du mois puis déclenche l'envoi via auth-service.
 * La réponse {queued:true} d'auth-service atteste du DÉCLENCHEMENT, pas de la
 * livraison (envoi asynchrone en setImmediate côté auth-service).
 * @param {string} month - 'YYYY-MM'
 * @param {object|null} user - utilisateur déclencheur (route debug) ou null (cron)
 * @returns {Promise<object>} le payload KPI envoyé
 */
async function sendMonthlyReport(month, user = null) {
  if (!INTERNAL_SECRET) {
    throw new Error('INTERNAL_SECRET absent — envoi du rapport mensuel impossible');
  }

  const payload = computeMonthlyKpis(month);

  await axios.post(
    `${AUTH_SERVICE_URL}/internal/notifications/send-to-roles`,
    { type: 'monthly_report', roles: REPORT_ROLES, payload },
    {
      headers: { 'x-internal-secret': INTERNAL_SECRET, 'Content-Type': 'application/json' },
      timeout: 10000,
    }
  );

  // Audit du déclenchement (mois calculé + rôles ciblés) — jamais de la livraison
  logAction({
    user_id:     user?.id         || null,
    user_name:   user?.name       || 'Système (cron mensuel)',
    user_role:   user?.roles?.[0] || 'system',
    action:      'send_monthly_report',
    target_type: 'report',
    target_id:   month,
    target_name: `Rapport mensuel ${payload.month_label}`,
    details:     { month, roles: REPORT_ROLES, issues_created: payload.issues_created },
  });

  console.log(`[DB] Rapport mensuel ${payload.month_label} déclenché vers ${REPORT_ROLES.join(', ')}`);
  return payload;
}

/**
 * Démarre le cron mensuel : le 1er du mois à 06h00, rapport du mois précédent.
 * À appeler dans index.js après getDb(). Ne s'exécute pas en environnement de test.
 * Le cron ne fait JAMAIS tomber le service : tout échec est loggé puis absorbé.
 */
function initMonthlyReportCron() {
  if (process.env.NODE_ENV === 'test') return;

  cron.schedule('0 6 1 * *', async () => {
    try {
      await sendMonthlyReport(previousMonth());
    } catch (err) {
      console.error('[DB] Échec du rapport mensuel :', err.message);
    }
  });

  console.log('[DB] Cron rapport mensuel activé : le 1er du mois à 06h00');
}

module.exports = { computeMonthlyKpis, sendMonthlyReport, initMonthlyReportCron, previousMonth, monthLabel };
