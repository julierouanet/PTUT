const axios = require('axios');
const { getDb } = require('../database');

const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://auth-service:3001';
const INTERNAL_SECRET  = process.env.INTERNAL_SECRET  || '';
const INTERVAL_MS      = 24 * 60 * 60 * 1000; // 24h

/**
 * Envoie une notification email PM à tous les techniciens et superviseurs.
 * Appelle POST /internal/notifications/send-to-roles sur auth-service.
 */
async function _notify(equipment, daysUntil) {
  if (!INTERNAL_SECRET) return; // sécurité : ne jamais appeler sans secret

  const url = `${AUTH_SERVICE_URL}/internal/notifications/send-to-roles`;
  try {
    await axios.post(
      url,
      {
        type: 'pm_due',
        roles: [
          'technician',
          'technician_biomedical',
          'technician_it',
          'technician_infra',
          'supervisor',
        ],
        payload: {
          equipment_name: equipment.name,
          department:     equipment.department,
          due_date:       equipment.next_preventive_maintenance,
          days_until:     daysUntil,
        },
      },
      {
        headers: {
          'x-internal-secret': INTERNAL_SECRET,
          'Content-Type': 'application/json',
        },
        timeout: 10000,
      }
    );
  } catch (err) {
    // Ne jamais crasher le service si auth-service est inaccessible
    console.warn(`[PM-JOB] Échec notification PM pour ${equipment.id}: ${err.message}`);
  }
}

/**
 * Vérifie les équipements dont la maintenance préventive arrive à échéance.
 * Exécutée toutes les 24h.
 */
function checkPmReminders() {
  const db = getDb();

  // Rappel J-7 : maintenance prévue dans exactement 7 jours
  const upcomingPm = db.prepare(`
    SELECT id, name, next_preventive_maintenance, department
    FROM equipment
    WHERE date(next_preventive_maintenance) = date('now', '+7 days')
      AND next_preventive_maintenance IS NOT NULL
  `).all();

  // Rappel J=0 : échéance aujourd'hui
  const overduePm = db.prepare(`
    SELECT id, name, next_preventive_maintenance, department
    FROM equipment
    WHERE date(next_preventive_maintenance) = date('now')
      AND next_preventive_maintenance IS NOT NULL
  `).all();

  for (const eq of upcomingPm) {
    _notify(eq, 7);
  }

  for (const eq of overduePm) {
    _notify(eq, 0);
  }

  if (upcomingPm.length > 0 || overduePm.length > 0) {
    console.log(
      `[PM-JOB] Rappels envoyés : ${upcomingPm.length} J-7, ${overduePm.length} J=0`
    );
  }
}

/**
 * Démarre le job quotidien de rappel PM.
 * Premier check dans 1h pour laisser le temps au service de démarrer.
 * Ne s'exécute pas en environnement de test.
 */
function startPmReminderJob() {
  if (process.env.NODE_ENV === 'test') return;

  // Premier déclenchement différé (1h après démarrage)
  setTimeout(() => {
    checkPmReminders();
    setInterval(checkPmReminders, INTERVAL_MS);
  }, 60 * 60 * 1000);

  console.log('[PM-JOB] Job de rappel PM démarré (premier check dans 1h, puis toutes les 24h)');
}

module.exports = { startPmReminderJob };
