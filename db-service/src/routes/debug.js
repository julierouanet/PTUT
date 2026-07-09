const express = require('express');
const XLSX = require('xlsx');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { AUTH_SERVICE_URL, INTERNAL_SECRET } = require('../config');
const { sendPushToUser } = require('../utils/push_sender');
const { xlsxUpload } = require('../middleware/upload');
const { seed } = require('../../seed');
const { seedReferences, importEquipment } = require('../../scripts/import_inventory');
const { sendMonthlyReport, previousMonth } = require('../jobs/monthly_report_job');

const router = express.Router();

// Intervalle de test des notifications — stocké en mémoire (réinitialisé au redémarrage du serveur)
let debugNotifyInterval = null;

// ── POST /clear-issues ────────────────────────────────────────────────────────
// Supprime tous les incidents (réservé admin, usage debug/test uniquement)
router.post('/clear-issues', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const result = db.prepare('DELETE FROM issues').run();

  logAction({
    user_id:     req.user.id,
    user_name:   req.user.name,
    user_role:   req.user.roles[0],
    action:      'debug_clear_all_issues',
    target_type: 'issues',
    target_id:   null,
    target_name: 'Tous les incidents',
    details:     JSON.stringify({ deleted_count: result.changes, note: 'Nettoyage complet des incidents' }),
    ...extractReqMeta(req),
  });

  res.json({ message: `${result.changes} incident(s) supprimé(s)`, deleted: result.changes });
});

// ── POST /reseed ──────────────────────────────────────────────────────────────
// Réinitialise les données d'INSTANCE (équipements, incidents, maintenance,
// inventaire, lieux) avec le jeu de démo de seed.js — réservé admin.
// Ne touche PAS aux tables de référence/catalogue (departments, equipment_categories,
// equipment_macro_categories, equipment_subcategories, equipment_brands,
// equipment_models, pm_protocols) : seules les instances créées par import/usage
// sont remises à zéro, pas la structure de catégorisation.
router.post('/reseed', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();

  const before = {
    equipment: db.prepare('SELECT COUNT(*) c FROM equipment').get().c,
    issues:    db.prepare('SELECT COUNT(*) c FROM issues').get().c,
    inventory: db.prepare('SELECT COUNT(*) c FROM inventory').get().c,
    locations: db.prepare('SELECT COUNT(*) c FROM locations').get().c,
  };

  const runReseed = db.transaction(() => {
    // `issues` puis `equipment` d'abord : les tables enfants (equipment_tags,
    // maintenance_records, preventive_maintenance_plans, equipment_documents,
    // issue_intervention_reports, issue_photos) sont en ON DELETE CASCADE.
    db.prepare('DELETE FROM issues').run();
    db.prepare('DELETE FROM equipment').run();
    db.prepare('DELETE FROM inventory').run();
    db.prepare('DELETE FROM locations').run();
    seed();
  });
  runReseed();

  const after = {
    equipment: db.prepare('SELECT COUNT(*) c FROM equipment').get().c,
    issues:    db.prepare('SELECT COUNT(*) c FROM issues').get().c,
    inventory: db.prepare('SELECT COUNT(*) c FROM inventory').get().c,
    locations: db.prepare('SELECT COUNT(*) c FROM locations').get().c,
  };

  logAction({
    user_id:     req.user.id,
    user_name:   req.user.name,
    user_role:   req.user.roles[0],
    action:      'debug_reseed_database',
    target_type: 'database',
    target_id:   null,
    target_name: 'Données de démo',
    details:     JSON.stringify({ before, after, note: 'Réinitialisation équipements/incidents/inventaire/lieux avec seed.js' }),
    ...extractReqMeta(req),
  });

  res.json({ message: 'Base de données réinitialisée avec les données de démo', before, after });
});

// ── POST /reseed-from-file ───────────────────────────────────────────────────
// Vide les équipements/incidents existants puis réimporte intégralement depuis
// un fichier XLSX fourni par l'admin (format "Equipment Migration Template",
// même structure que scripts/import_inventory.js : feuilles Standard_Departments,
// Standard_Equipment_Names, Equipment Migration Template).
router.post('/reseed-from-file', verifyToken, requireRole('admin'), xlsxUpload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Fichier .xlsx manquant (champ "file")' });
  }

  let workbook;
  try {
    workbook = XLSX.read(req.file.buffer, { cellDates: true });
  } catch (err) {
    return res.status(400).json({ error: `Fichier XLSX illisible : ${err.message}` });
  }

  const requiredSheets = ['Standard_Departments', 'Standard_Equipment_Names', 'Equipment Migration Template'];
  const missing = requiredSheets.filter(s => !workbook.Sheets[s]);
  if (missing.length) {
    return res.status(400).json({ error: `Feuille(s) manquante(s) dans le fichier : ${missing.join(', ')}` });
  }

  const db = getDb();
  const before = { equipment: db.prepare('SELECT COUNT(*) c FROM equipment').get().c };

  let importResult;
  try {
    const runReseed = db.transaction(() => {
      // `issues` puis `equipment` d'abord : equipment_tags, maintenance_records,
      // preventive_maintenance_plans, equipment_documents sont en ON DELETE CASCADE.
      db.prepare('DELETE FROM issues').run();
      db.prepare('DELETE FROM equipment').run();
      seedReferences(db, workbook, false);
      importResult = importEquipment(db, workbook, { insertOnly: false });
    });
    runReseed();
  } catch (err) {
    return res.status(500).json({ error: `Échec de l'import : ${err.message}` });
  }

  const after = { equipment: db.prepare('SELECT COUNT(*) c FROM equipment').get().c };

  logAction({
    user_id:     req.user.id,
    user_name:   req.user.name,
    user_role:   req.user.roles[0],
    action:      'debug_reseed_from_file',
    target_type: 'database',
    target_id:   null,
    target_name: req.file.originalname,
    details:     JSON.stringify({ before, after, stats: importResult.stats, note: 'Réinitialisation équipements depuis fichier XLSX uploadé' }),
    ...extractReqMeta(req),
  });

  res.json({
    message: `Base de données régénérée depuis "${req.file.originalname}"`,
    before, after,
    stats: importResult.stats,
    errors: importResult.errors.slice(0, 20),
  });
});

// ── POST /notify-now ──────────────────────────────────────────────────────────
// Envoie une notification email de test immédiate à l'administrateur appelant.
router.post('/notify-now', verifyToken, requireRole('admin'), async (req, res) => {
  const userId    = req.user.id;
  const userEmail = req.user.email;
  const userName  = req.user.name;

  if (!userEmail) {
    return res.status(400).json({ success: false, error: 'Email introuvable dans le token' });
  }

  try {
    // Appel auth-service : type critical_new_issue avec payload de test
    const resp = await fetch(`${AUTH_SERVICE_URL}/internal/notifications/send-email`, {
      method:  'POST',
      headers: {
        'Content-Type':      'application/json',
        'x-internal-secret': INTERNAL_SECRET,
      },
      body: JSON.stringify({
        type:     'critical_new_issue',
        to_email: userEmail,
        to_name:  userName,
        user_id:  userId,
        payload: {
          equipment_name: '[TEST] Notification de débogage GMAO',
          department:     req.user.department || 'Administration',
          description:    'Ceci est une notification de test envoyée depuis le panneau admin debug.',
          reporter_name:  userName,
          issue_id:       'DEBUG-TEST',
        },
      }),
    });

    const body = await resp.json().catch(() => ({}));

    if (!resp.ok) {
      console.error('[debug/notify-now] Erreur auth-service:', body);
      return res.status(500).json({ success: false, error: body.error || `HTTP ${resp.status}` });
    }

    // Notification push immédiate (fire-and-forget) — indépendante des préférences email
    sendPushToUser(userId, {
      title: '[TEST] Notification de débogage GMAO',
      body:  'Notification immédiate envoyée depuis le panneau admin debug.',
    }).catch((err) => console.error('[debug/notify-now] Erreur push:', err.message));

    // Persistance in-app de la notification debug dans la table notifications
    try {
      const db = getDb();
      db.prepare(`
        INSERT INTO notifications (user_id, type, title, body, target_type)
        VALUES (?, ?, ?, ?, ?)
      `).run(
        userId,
        'critical_new_issue',
        '[TEST] Notification de débogage GMAO',
        'Notification de test déclenchée depuis DebugTestScreen',
        null
      );
    } catch (dbErr) {
      console.error('[debug/notify-now] Erreur persistance notif:', dbErr.message);
    }

    logAction({
      user_id:     userId,
      user_name:   userName,
      user_role:   req.user.roles[0],
      action:      'debug_notify_now',
      target_type: 'user',
      target_id:   userId,
      target_name: userEmail,
      details:     JSON.stringify({ sent: body.sent, reason: body.reason }),
      ...extractReqMeta(req),
    });

    return res.json({ success: true, message: `Notification envoyée à ${userEmail}`, sent: body.sent, reason: body.reason });
  } catch (err) {
    console.error('[debug/notify-now] Erreur:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// ── POST /send-monthly-report ─────────────────────────────────────────────────
// Relance exactement le même calcul + envoi que le cron mensuel (test/debug).
// Paramètre optionnel ?month=YYYY-MM (défaut : mois civil précédent).
router.post('/send-monthly-report', verifyToken, requireRole('admin'), async (req, res) => {
  const month = req.query.month || previousMonth();

  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) {
    return res.status(400).json({ error: 'Paramètre month invalide — format attendu : YYYY-MM' });
  }

  try {
    // sendMonthlyReport pose le logAction du déclenchement (utilisateur fourni)
    const payload = await sendMonthlyReport(month, req.user);
    return res.json({
      success: true,
      message: `Rapport mensuel ${payload.month_label} déclenché (envoi asynchrone côté auth-service)`,
      month,
      kpis: payload,
    });
  } catch (err) {
    console.error('[debug/send-monthly-report] Erreur:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// ── POST /notify-schedule ─────────────────────────────────────────────────────
// Active ou désactive les notifications email de test à intervalle fixe (in-memory).
router.post('/notify-schedule', verifyToken, requireRole('admin'), async (req, res) => {
  const { interval } = req.body;

  if (!interval || !['minute', 'hour', 'stop'].includes(interval)) {
    return res.status(400).json({
      success: false,
      error: 'Paramètre "interval" manquant ou invalide. Valeurs acceptées : minute | hour | stop',
    });
  }

  try {
    // Cas : arrêt du scheduling
    if (interval === 'stop') {
      if (debugNotifyInterval) {
        clearInterval(debugNotifyInterval);
        debugNotifyInterval = null;

        logAction({
          user_id:     req.user.id,
          user_name:   req.user.name,
          user_role:   req.user.roles[0],
          action:      'debug_notify_stop',
          target_type: 'system',
          target_id:   null,
          target_name: 'debug-scheduler',
          details:     JSON.stringify({ note: 'Notifications automatiques de test arrêtées' }),
          ...extractReqMeta(req),
        });

        return res.json({ success: true, status: 'stopped' });
      }
      return res.json({ success: true, status: 'already_stopped' });
    }

    // Éviter les fuites : supprimer l'intervalle existant avant d'en créer un nouveau
    if (debugNotifyInterval) {
      clearInterval(debugNotifyInterval);
      debugNotifyInterval = null;
    }

    // Captures pour le setInterval (req sera périmé à l'exécution différée)
    const userId    = req.user.id;
    const userEmail = req.user.email;
    const userName  = req.user.name;
    const userDept  = req.user.department || 'Administration';

    const delay = interval === 'minute' ? 60_000 : 3_600_000;
    debugNotifyInterval = setInterval(async () => {
      try {
        // Notification push (immédiate, visible dans le navigateur)
        await sendPushToUser(userId, {
          title: `[TEST AUTO] Notification GMAO (${interval})`,
          body:  `Notification automatique de test — intervalle : ${interval}.`,
        });

        // Email via auth-service (respecte les préférences utilisateur)
        await fetch(`${AUTH_SERVICE_URL}/internal/notifications/send-email`, {
          method:  'POST',
          headers: {
            'Content-Type':      'application/json',
            'x-internal-secret': INTERNAL_SECRET,
          },
          body: JSON.stringify({
            type:     'critical_new_issue',
            to_email: userEmail,
            to_name:  userName,
            user_id:  userId,
            payload: {
              equipment_name: `[TEST AUTO] Notification debug — intervalle : ${interval}`,
              department:     userDept,
              description:    `Notification automatique de test (intervalle : ${interval}).`,
              reporter_name:  userName,
              issue_id:       'DEBUG-AUTO',
            },
          }),
        });
        console.log(`[debug/notify-schedule] Push + email envoyés (${interval})`);
      } catch (err) {
        console.error('[debug/notify-schedule] Erreur envoi auto:', err.message);
      }
    }, delay);

    logAction({
      user_id:     req.user.id,
      user_name:   req.user.name,
      user_role:   req.user.roles[0],
      action:      'debug_notify_start',
      target_type: 'system',
      target_id:   null,
      target_name: 'debug-scheduler',
      details:     JSON.stringify({ interval, note: 'Notifications automatiques de test activées' }),
      ...extractReqMeta(req),
    });

    return res.json({ success: true, status: 'started', interval });
  } catch (err) {
    console.error('[debug/notify-schedule] Erreur:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// ── POST /notify-broadcast ────────────────────────────────────────────────────
// Déclenche une diffusion de test vers un ou plusieurs rôles, via send-to-roles.
router.post('/notify-broadcast', verifyToken, requireRole('admin'), async (req, res) => {
  const { roles, type } = req.body;

  const VALID_TYPES = [
    'critical_new_issue', 'critical_acknowledged', 'critical_diagnosed',
    'critical_resolved', 'monthly_report', 'pm_due',
  ];

  if (!Array.isArray(roles) || roles.length === 0) {
    return res.status(400).json({ success: false, error: 'roles[] requis et non vide' });
  }
  if (!type || !VALID_TYPES.includes(type)) {
    return res.status(400).json({ success: false, error: `type invalide. Valeurs acceptées : ${VALID_TYPES.join(', ')}` });
  }

  // Payloads de test fixes par type — champs minimaux attendus par buildEmailContent
  // (auth-service/src/utils/email_service.js:150-428), valeurs '[TEST]' explicites.
  const TEST_BASE = { equipment_name: '[TEST] Diffusion debug', department: 'Administration', issue_id: 'DEBUG-BROADCAST' };
  const TEST_PAYLOADS = {
    critical_new_issue: {
      ...TEST_BASE, urgency: 'Critique',
      description: 'Notification de diffusion de test envoyée depuis le panneau admin debug.',
      reporter_name: req.user.name,
    },
    critical_acknowledged: {
      ...TEST_BASE, technician_name: req.user.name,
    },
    critical_diagnosed: {
      ...TEST_BASE, technician_name: req.user.name, diagnosis: 'Diagnostic de test.',
    },
    critical_resolved: {
      ...TEST_BASE, technician_name: req.user.name,
      created_at: new Date(Date.now() - 3600_000).toISOString(), resolved_at: new Date().toISOString(),
      diagnosis: 'Diagnostic de test.', actions: 'Actions de test.', parts_replaced: 'Aucune',
    },
    monthly_report: {
      month_label: '[TEST] Mois de démonstration', issues_created: 0, issues_resolved: 0,
      issues_still_open: 0, by_urgency: {}, mttr_hours: null, pm_compliance_pct: null,
      equipment_out_of_service: 0, top_equipment: [],
    },
    pm_due: { equipment_name: TEST_BASE.equipment_name, department: TEST_BASE.department },
  };

  try {
    const resp = await fetch(`${AUTH_SERVICE_URL}/internal/notifications/send-to-roles`, {
      method:  'POST',
      headers: {
        'Content-Type':      'application/json',
        'x-internal-secret': INTERNAL_SECRET,
      },
      body: JSON.stringify({
        type,
        roles,
        payload: TEST_PAYLOADS[type],
        triggered_by: { user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles[0] },
      }),
    });

    const body = await resp.json().catch(() => ({}));
    if (!resp.ok) {
      return res.status(500).json({ success: false, error: body.error || `HTTP ${resp.status}` });
    }

    return res.json({ success: true, message: `Diffusion de test lancée vers : ${roles.join(', ')}`, queued: body.queued });
  } catch (err) {
    console.error('[debug/notify-broadcast] Erreur:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /notification-logs ────────────────────────────────────────────────────
// Historique formaté des diffusions send-to-roles (prod + test), le plus récent d'abord.
router.get('/notification-logs', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const limit = Math.min(parseInt(req.query.limit, 10) || 20, 100);

  const rows = db.prepare(
    `SELECT id, timestamp, user_name, user_role, target_name, details
     FROM logs WHERE action = 'notify_send_to_roles'
     ORDER BY timestamp DESC LIMIT ?`
  ).all(limit);

  const formatted = rows.map(r => {
    let details = {};
    try { details = JSON.parse(r.details || '{}'); } catch (_) {}
    return {
      id: r.id,
      timestamp: r.timestamp,
      triggered_by: r.user_name,
      triggered_role: r.user_role,
      roles: r.target_name,
      type: details.type || null,
      attempted: details.attempted ?? null,
      filtered: details.filtered ?? null,
      recipients: details.recipients ?? null,
    };
  });

  res.json(formatted);
});

router.get('/', (req, res) => {
  const db = getDb();

  const equipment  = db.prepare('SELECT * FROM equipment ORDER BY department, name').all();
  const issues     = db.prepare('SELECT * FROM issues ORDER BY created_at DESC').all();
  const inventory  = db.prepare('SELECT * FROM inventory ORDER BY name').all();

  const stats = {
    equipment:  equipment.length,
    issues:     issues.length,
    inventory:  inventory.length,
    issuesOpen: issues.filter(i => i.status === 'Ouvert').length,
    issuesInProgress: issues.filter(i => i.status === 'En cours').length,
    issuesResolved: issues.filter(i => i.status === 'Résolu').length,
    stockLow: inventory.filter(i => i.status === 'Faible').length,
    stockOut: inventory.filter(i => i.status === 'Rupture').length,
  };

  const statusColors = {
    'Operational':    '#27ae60',
    'Maintenance':    '#f39c12',
    'Out of service': '#e74c3c',
    'To be disposal': '#e67e22',
    'Disposed':       '#95a5a6',
    'Ouvert':         '#e74c3c',
    'En cours':       '#f39c12',
    'Résolu':         '#27ae60',
    'Normal':         '#27ae60',
    'Faible':         '#f39c12',
    'Rupture':        '#e74c3c',
  };

  const badge = (val) => `<span style="background:${statusColors[val]||'#95a5a6'};color:white;padding:2px 8px;border-radius:12px;font-size:11px;white-space:nowrap">${val}</span>`;

  const equipRows = equipment.map(e => `
    <tr>
      <td><code>${e.id}</code></td>
      <td>${e.name}</td>
      <td>${e.department}</td>
      <td>${e.category}</td>
      <td>${badge(e.status)}</td>
      <td>${e.serial_number || '-'}</td>
      <td>${e.supplier || '-'}</td>
      <td>${e.location || '-'}</td>
    </tr>`).join('');

  const issueRows = issues.map(i => `
    <tr>
      <td><code>${i.id}</code></td>
      <td>${i.equipment_name}</td>
      <td>${i.department}</td>
      <td>${i.description.substring(0, 60)}${i.description.length > 60 ? '…' : ''}</td>
      <td>${badge(i.status)}</td>
      <td>${i.reporter}</td>
      <td>${i.assigned_technician || '-'}</td>
      <td>${i.created_at}</td>
    </tr>`).join('');

  const inventoryRows = inventory.map(i => `
    <tr>
      <td><code>${i.id}</code></td>
      <td>${i.name}</td>
      <td>${i.category}</td>
      <td>${i.current_stock} ${i.unit}</td>
      <td>${i.min_stock} ${i.unit}</td>
      <td>${badge(i.status)}</td>
      <td>${i.last_restocked || '-'}</td>
    </tr>`).join('');

  res.send(`<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>DB Service - Debug</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f0f2f5; color: #333; }
    .header { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 24px 32px; }
    .header h1 { font-size: 24px; font-weight: 700; }
    .header p { opacity: 0.85; font-size: 14px; margin-top: 4px; }
    .container { max-width: 1400px; margin: 0 auto; padding: 24px 32px; }
    .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 16px; margin-bottom: 32px; }
    .stat-card { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
    .stat-card .value { font-size: 32px; font-weight: 700; color: #11998e; }
    .stat-card .label { font-size: 13px; color: #888; margin-top: 4px; }
    .tabs { display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap; }
    .tab-btn { padding: 8px 20px; border: none; border-radius: 8px; cursor: pointer; font-size: 14px; font-weight: 600; background: #e0e0e0; color: #555; transition: all 0.2s; }
    .tab-btn.active { background: #11998e; color: white; }
    .section { background: white; border-radius: 12px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); overflow-x: auto; }
    .section h2 { font-size: 18px; font-weight: 600; margin-bottom: 16px; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; min-width: 700px; }
    th { text-align: left; padding: 10px 12px; background: #f8f9fa; font-weight: 600; color: #555; border-bottom: 2px solid #eee; }
    td { padding: 9px 12px; border-bottom: 1px solid #f0f0f0; vertical-align: middle; }
    tr:hover td { background: #f0fdf8; }
    code { background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-size: 11px; }
    .panel { display: none; }
    .panel.active { display: block; }
    .env-badge { background: #f39c12; color: white; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; }
  </style>
</head>
<body>
  <div class="header">
    <h1>🗄️ DB Service — Debug Dashboard</h1>
    <p>Hôpital de Kabutare — Environnement: <span class="env-badge">${process.env.NODE_ENV || 'development'}</span></p>
  </div>
  <div class="container">
    <div class="stats">
      <div class="stat-card"><div class="value">${stats.equipment}</div><div class="label">Équipements</div></div>
      <div class="stat-card"><div class="value">${stats.issuesOpen}</div><div class="label">Incidents ouverts</div></div>
      <div class="stat-card"><div class="value">${stats.issuesInProgress}</div><div class="label">En cours</div></div>
      <div class="stat-card"><div class="value">${stats.issuesResolved}</div><div class="label">Résolus</div></div>
      <div class="stat-card"><div class="value">${stats.inventory}</div><div class="label">Articles stock</div></div>
      <div class="stat-card"><div class="value" style="color:#e74c3c">${stats.stockOut}</div><div class="label">En rupture</div></div>
      <div class="stat-card"><div class="value" style="color:#f39c12">${stats.stockLow}</div><div class="label">Stock faible</div></div>
    </div>

    <div class="tabs">
      <button class="tab-btn active" onclick="showTab('equipment')">🔧 Équipements (${stats.equipment})</button>
      <button class="tab-btn" onclick="showTab('issues')">⚠️ Incidents (${stats.issues})</button>
      <button class="tab-btn" onclick="showTab('inventory')">📦 Inventaire (${stats.inventory})</button>
    </div>

    <div id="tab-equipment" class="panel active section">
      <h2>🔧 Équipements</h2>
      <table>
        <thead><tr><th>ID</th><th>Nom</th><th>Département</th><th>Catégorie</th><th>Statut</th><th>N° Série</th><th>Fournisseur</th><th>Localisation</th></tr></thead>
        <tbody>${equipRows || '<tr><td colspan="8" style="text-align:center;color:#999">Aucun équipement</td></tr>'}</tbody>
      </table>
    </div>

    <div id="tab-issues" class="panel section">
      <h2>⚠️ Incidents</h2>
      <table>
        <thead><tr><th>ID</th><th>Équipement</th><th>Département</th><th>Description</th><th>Statut</th><th>Signalé par</th><th>Technicien</th><th>Date</th></tr></thead>
        <tbody>${issueRows || '<tr><td colspan="8" style="text-align:center;color:#999">Aucun incident</td></tr>'}</tbody>
      </table>
    </div>

    <div id="tab-inventory" class="panel section">
      <h2>📦 Inventaire</h2>
      <table>
        <thead><tr><th>ID</th><th>Nom</th><th>Catégorie</th><th>Stock actuel</th><th>Stock min</th><th>Statut</th><th>Dernier réapprovisionnement</th></tr></thead>
        <tbody>${inventoryRows || '<tr><td colspan="7" style="text-align:center;color:#999">Aucun article</td></tr>'}</tbody>
      </table>
    </div>
  </div>

  <script>
    function showTab(name) {
      document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.getElementById('tab-' + name).classList.add('active');
      event.target.classList.add('active');
    }
  </script>
</body>
</html>`);
});

router.get('/health', (req, res) => {
  let dbStatus = 'ko';
  try {
    getDb().prepare('SELECT 1').get();
    dbStatus = 'ok';
  } catch (_) {}

  res.json({
    status:    dbStatus === 'ok' ? 'ok' : 'degraded',
    service:   'db-service',
    timestamp: new Date().toISOString(),
    checks:    { database: dbStatus },
  });
});

module.exports = router;
