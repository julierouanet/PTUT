const express = require('express');
const path = require('path');
const fs = require('fs');
const cron = require('node-cron');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const config = require('../config');

const router = express.Router();

// Répertoire des sauvegardes — à côté de hospital.db dans le volume de données
const BACKUPS_DIR = path.join(path.dirname(path.resolve(config.DB_PATH)), 'backups');

// Référence à la tâche cron courante (rechargeable dynamiquement)
let currentCronTask = null;

// ── Helpers privés ─────────────────────────────────────────────────────────────

/**
 * Formate une taille en octets en chaîne lisible.
 */
function _formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

/**
 * Arrête et remplace la tâche cron en cours par une nouvelle planification.
 */
function _scheduleCron(cronExpr) {
  if (currentCronTask) {
    currentCronTask.stop();
    currentCronTask = null;
  }
  if (!cron.validate(cronExpr)) {
    console.error(`[BACKUP] Expression cron invalide : ${cronExpr}`);
    return;
  }
  currentCronTask = cron.schedule(cronExpr, () => {
    _performBackup({ automated: true }).catch((err) => {
      console.error('[BACKUP] Erreur sauvegarde automatique :', err.message);
    });
  });
}

/**
 * Effectue la sauvegarde physique via db.backup() de better-sqlite3.
 * Enregistre l'opération dans backup_history et génère un audit log.
 *
 * @param {Object}  opts
 * @param {boolean} opts.automated - true si déclenchée par le cron
 * @param {Object}  opts.user      - req.user (null pour les tâches automatisées)
 * @param {Object}  opts.req       - req Express (null pour les tâches automatisées)
 */
async function _performBackup({ automated = false, user = null, req = null } = {}) {
  // Créer le répertoire s'il n'existe pas encore
  if (!fs.existsSync(BACKUPS_DIR)) {
    fs.mkdirSync(BACKUPS_DIR, { recursive: true });
  }

  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const timestamp = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}-${pad(now.getMinutes())}-${pad(now.getSeconds())}`;
  const filename = `hospital_backup_${timestamp}.db`;
  const destPath = path.join(BACKUPS_DIR, filename);

  const db = getDb();
  let status = 'success';
  let fileSize = null;

  try {
    // db.backup() de better-sqlite3 est sûr à chaud — retourne une Promise
    await db.backup(destPath);
    const stats = fs.statSync(destPath);
    fileSize = _formatSize(stats.size);
  } catch (err) {
    status = 'error';
    console.error('[BACKUP] Erreur lors de la sauvegarde :', err.message);
    throw err;
  } finally {
    // Enregistrement dans l'historique (même en cas d'erreur)
    try {
      db.prepare(`
        INSERT INTO backup_history (filename, backup_type, status, file_size, created_at)
        VALUES (?, ?, ?, ?, datetime('now','localtime'))
      `).run(filename, automated ? 'automated' : 'manual', status, fileSize);

      logAction({
        user_id:     user?.id              || null,
        user_name:   user?.name            || 'Système (automatique)',
        user_role:   user?.roles?.[0]      || 'system',
        action:      automated ? 'backup_automated' : 'backup_manual',
        target_type: 'backup',
        target_id:   filename,
        target_name: filename,
        details:     { status, file_size: fileSize, type: automated ? 'automated' : 'manual' },
        ...(req ? extractReqMeta(req) : {}),
      });
    } catch (_) {}
  }

  return { filename, fileSize, status };
}

// ── Initialisation cron au démarrage ──────────────────────────────────────────

/**
 * À appeler dans index.js après getDb() pour activer la planification persistée.
 */
function initBackupCron() {
  const db = getDb();
  const settings = db.prepare("SELECT * FROM backup_settings WHERE id = 'default'").get();
  if (settings && settings.is_automated === 1 && settings.cron_schedule) {
    _scheduleCron(settings.cron_schedule);
    console.log(`[DB] Sauvegarde automatique activée : ${settings.cron_schedule}`);
  }
}

// ── GET /api/admin/backups ─────────────────────────────────────────────────────
router.get('/', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const settings = db.prepare("SELECT * FROM backup_settings WHERE id = 'default'").get();
  const history = db.prepare(
    'SELECT * FROM backup_history ORDER BY created_at DESC LIMIT 50'
  ).all();

  res.json({
    settings: {
      cron_schedule: settings?.cron_schedule || '0 0 * * *',
      is_automated:  settings?.is_automated  === 1,
      updated_at:    settings?.updated_at    || null,
    },
    history,
  });
});

// ── POST /api/admin/backups/trigger ───────────────────────────────────────────
router.post('/trigger', verifyToken, requireRole('admin'), async (req, res) => {
  try {
    const result = await _performBackup({ automated: false, user: req.user, req });
    res.json({ message: 'Sauvegarde effectuée avec succès', ...result });
  } catch (err) {
    console.error('[BACKUP] Erreur déclenchement manuel :', err.message);
    res.status(500).json({ error: 'Erreur lors de la sauvegarde : ' + err.message });
  }
});

// ── POST /api/admin/backups/settings ──────────────────────────────────────────
router.post('/settings', verifyToken, requireRole('admin'), (req, res) => {
  const { cron_schedule, is_automated } = req.body;

  if (typeof is_automated !== 'boolean') {
    return res.status(400).json({ error: 'is_automated (boolean) requis' });
  }
  if (cron_schedule && !cron.validate(cron_schedule)) {
    return res.status(400).json({ error: 'Expression cron invalide' });
  }

  const schedule = cron_schedule || '0 0 * * *';
  const db = getDb();

  db.prepare(`
    UPDATE backup_settings
       SET cron_schedule = ?, is_automated = ?, updated_at = datetime('now','localtime')
     WHERE id = 'default'
  `).run(schedule, is_automated ? 1 : 0);

  // Recharger ou arrêter la tâche cron selon le paramètre
  if (is_automated) {
    _scheduleCron(schedule);
    console.log(`[DB] Sauvegarde automatique replanifiée : ${schedule}`);
  } else {
    if (currentCronTask) {
      currentCronTask.stop();
      currentCronTask = null;
    }
    console.log('[DB] Sauvegarde automatique désactivée');
  }

  logAction({
    user_id:     req.user.id,
    user_name:   req.user.name,
    user_role:   req.user.roles[0],
    action:      'update_backup_settings',
    target_type: 'backup_settings',
    target_id:   'default',
    target_name: 'Paramètres de sauvegarde',
    details:     { cron_schedule: schedule, is_automated },
    ...extractReqMeta(req),
  });

  res.json({ message: 'Paramètres de sauvegarde mis à jour' });
});

// ── GET /api/admin/backups/download/:id ───────────────────────────────────────
router.get('/download/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const record = db.prepare('SELECT * FROM backup_history WHERE id = ?').get(req.params.id);
  if (!record) return res.status(404).json({ error: 'Sauvegarde introuvable' });

  const filePath = path.join(BACKUPS_DIR, record.filename);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'Fichier de sauvegarde introuvable sur le serveur' });
  }

  logAction({
    user_id:     req.user.id,
    user_name:   req.user.name,
    user_role:   req.user.roles[0],
    action:      'download_backup',
    target_type: 'backup',
    target_id:   String(record.id),
    target_name: record.filename,
    details:     { filename: record.filename },
    ...extractReqMeta(req),
  });

  res.download(filePath, record.filename);
});

module.exports = { router, initBackupCron };
