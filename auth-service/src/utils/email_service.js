// ── Service d'envoi d'emails via l'API REST Brevo ─────────────────────────────
// Utilisé pour les notifications applicatives centrées sur les incidents CRITIQUES.
// Distinct du SMTP Keycloak utilisé pour reset/vérification de compte.

'use strict';

const config = require('../config');
const { getDb } = require('../database');

const BREVO_SMTP_URL = 'https://api.brevo.com/v3/smtp/email';

// Statement compilé une seule fois au chargement du module (réutilisé à chaque envoi)
let _brevoConfigStmt = null;

/**
 * Lit la config Brevo depuis app_settings (base de données),
 * avec fallback sur les variables d'environnement si la valeur DB est vide.
 */
function _getBrevoConfig() {
  try {
    if (!_brevoConfigStmt) {
      _brevoConfigStmt = getDb().prepare(
        "SELECT key, value FROM app_settings WHERE key IN ('brevo_api_key','brevo_sender_email','brevo_sender_name')"
      );
    }
    const map = {};
    for (const r of _brevoConfigStmt.all()) map[r.key] = r.value || '';

    return {
      apiKey:      map['brevo_api_key']      || config.BREVO_API_KEY,
      senderEmail: map['brevo_sender_email'] || config.BREVO_SENDER_EMAIL,
      senderName:  map['brevo_sender_name']  || config.BREVO_SENDER_NAME,
    };
  } catch (_) {
    // En cas d'erreur DB (ex: DB non encore ouverte), retomber sur l'env
    _brevoConfigStmt = null;
    return {
      apiKey:      config.BREVO_API_KEY,
      senderEmail: config.BREVO_SENDER_EMAIL,
      senderName:  config.BREVO_SENDER_NAME,
    };
  }
}

// ── Utilitaires ────────────────────────────────────────────────────────────────

const ROUGE  = '#D32F2F';
const ORANGE = '#F57C00';
const VERT   = '#388E3C';
const BLEU   = '#1565C0';
const GRIS   = '#757575';

// Style visuel de l'email "nouvel incident" selon l'urgence réelle de l'incident.
const URGENCY_STYLE = {
  Critique: { color: ROUGE,  bg: '#FFEBEE', emoji: '🚨', action: "Votre intervention est requise en priorité." },
  Urgent:   { color: ORANGE, bg: '#FFF3E0', emoji: '⚠️', action: "Une intervention rapide est attendue." },
  Moyen:    { color: BLEU,   bg: '#E3F2FD', emoji: 'ℹ️', action: "Un incident a été signalé dans votre groupe technique." },
  Faible:   { color: GRIS,   bg: '#F5F5F5', emoji: 'ℹ️', action: "Un incident a été signalé dans votre groupe technique." },
};

/** Formate une durée en millisecondes en texte lisible (ex: "2h 15min"). */
function _formatDuration(ms) {
  if (!ms || ms <= 0) return '—';
  const totalMin = Math.round(ms / 60000);
  const h   = Math.floor(totalMin / 60);
  const min = totalMin % 60;
  if (h === 0) return `${min} min`;
  if (min === 0) return `${h} h`;
  return `${h} h ${min} min`;
}

/** Pied de page commun à tous les emails. */
const _footer = `
  <hr style="margin-top:28px;border:none;border-top:1px solid #e0e0e0">
  <p style="color:${GRIS};font-size:11px;margin:8px 0 0">
    GMAO — Hôpital de District de Kabutare · Rwanda<br>
    Cet email est envoyé automatiquement — merci de ne pas y répondre.
  </p>
`;

/** Génère une ligne de tableau de données. */
function _row(label, value, valueColor) {
  return `
    <tr>
      <td style="padding:6px 12px 6px 0;color:${GRIS};white-space:nowrap;vertical-align:top;font-size:13px">${label}</td>
      <td style="padding:6px 0;font-size:13px;${valueColor ? `color:${valueColor};font-weight:600` : ''}">${value || '—'}</td>
    </tr>
  `;
}

/**
 * Envoie un email transactionnel via l'API Brevo.
 * Fire-and-forget : loggue les erreurs sans lever d'exception.
 */
async function sendEmail({ to, toName, subject, htmlContent, textContent }) {
  const { apiKey, senderEmail, senderName } = _getBrevoConfig();

  if (!apiKey) {
    console.warn('[EMAIL] BREVO_API_KEY absent — email non envoyé à', to);
    return;
  }
  if (!to || !subject) {
    console.warn('[EMAIL] Paramètres manquants — email ignoré');
    return;
  }

  try {
    const resp = await fetch(BREVO_SMTP_URL, {
      method: 'POST',
      headers: {
        'api-key':      apiKey,
        'Content-Type': 'application/json',
        'Accept':       'application/json',
      },
      body: JSON.stringify({
        sender:      { email: senderEmail, name: senderName },
        to:          [{ email: to, name: toName || to }],
        subject,
        htmlContent,
        ...(textContent ? { textContent } : {}),
      }),
    });

    if (!resp.ok) {
      const txt = await resp.text().catch(() => '');
      console.error(`[EMAIL] Brevo ${resp.status} → ${to}: ${txt.substring(0, 200)}`);
    } else {
      console.log(`[EMAIL] ✓ Envoyé à ${to} — "${subject}"`);
    }
  } catch (err) {
    console.error(`[EMAIL] Exception → ${to}: ${err.message}`);
  }
}

/**
 * Construit le contenu HTML + texte d'un email selon le type d'événement.
 *
 * Types supportés :
 *   critical_new_issue    → techniciens : nouvel incident (couleur/ton selon urgence réelle)
 *   critical_acknowledged → superviseurs : technicien a pris en charge
 *   critical_diagnosed    → superviseurs : diagnostic posé
 *   critical_resolved     → superviseurs : incident résolu (KPIs)
 *   pm_due                → techniciens/admins : maintenance préventive à planifier
 *   monthly_report        → superviseurs/admins : synthèse KPI GMAO du mois écoulé
 *
 * @param {string} type
 * @param {object} payload
 * @returns {{ subject: string, htmlContent: string, textContent: string } | null}
 */
function buildEmailContent(type, payload = {}) {
  const {
    issue_id,
    equipment_name,
    department,
    urgency = 'Critique',
    reporter_name,
    technician_name,
    description,
    // KPIs résolution
    created_at,
    resolved_at,
    diagnosis,
    actions,
    parts_replaced,
  } = payload;

  const equipLabel = equipment_name || 'Équipement non spécifié';
  const deptLabel  = department     || '—';

  switch (type) {

    // ── Technicien : nouvel incident signalé (seuil d'urgence configurable) ────
    case 'critical_new_issue': {
      const style = URGENCY_STYLE[urgency] || URGENCY_STYLE.Critique;

      const subject = `${style.emoji} [${urgency.toUpperCase()}] Nouvel incident — ${equipLabel} · ${deptLabel}`;
      const htmlContent = `
        <div style="font-family:Arial,sans-serif;max-width:600px;color:#212121">
          <div style="background:${style.color};padding:16px 24px;border-radius:6px 6px 0 0">
            <h2 style="color:#fff;margin:0;font-size:18px">${style.emoji} Incident ${urgency} signalé</h2>
          </div>
          <div style="border:1px solid #e0e0e0;border-top:none;border-radius:0 0 6px 6px;padding:20px 24px">
            <p style="margin:0 0 16px;font-size:14px;color:${GRIS}">
              Un incident de niveau <strong style="color:${style.color}">${urgency}</strong> vient d'être signalé dans votre groupe technique.
              ${style.action}
            </p>
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;width:100%">
              ${_row('Équipement', `<strong>${equipLabel}</strong>`)}
              ${_row('Département', deptLabel)}
              ${_row('Description', description ? description.substring(0, 200) : null)}
              ${_row('Signalé par', reporter_name)}
              ${_row('N° incident', issue_id)}
            </table>
            <div style="margin-top:20px;padding:12px;background:${style.bg};border-radius:4px;border-left:4px solid ${style.color}">
              <p style="margin:0;font-size:13px;color:${style.color}"><strong>Action requise :</strong> Prenez en charge cet incident dès que possible via l'application GMAO.</p>
            </div>
          </div>
          ${_footer}
        </div>
      `;
      const textContent = `INCIDENT ${urgency.toUpperCase()} - ${equipLabel} (${deptLabel})\nSignalé par: ${reporter_name || '—'}\nDescription: ${description || '—'}\nN° incident: ${issue_id || '—'}`;
      return { subject, htmlContent, textContent };
    }

    // ── Superviseur : technicien a pris en charge un incident critique ─────────
    case 'critical_acknowledged': {
      const subject = `⚙️ [CRITIQUE] Pris en charge par ${technician_name || 'un technicien'} — ${equipLabel}`;
      const htmlContent = `
        <div style="font-family:Arial,sans-serif;max-width:600px;color:#212121">
          <div style="background:${ORANGE};padding:16px 24px;border-radius:6px 6px 0 0">
            <h2 style="color:#fff;margin:0;font-size:18px">⚙️ Incident critique pris en charge</h2>
          </div>
          <div style="border:1px solid #e0e0e0;border-top:none;border-radius:0 0 6px 6px;padding:20px 24px">
            <p style="margin:0 0 16px;font-size:14px;color:${GRIS}">
              Le technicien <strong>${technician_name || '—'}</strong> vient de prendre en charge l'incident critique ci-dessous.
            </p>
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;width:100%">
              ${_row('Équipement', `<strong>${equipLabel}</strong>`)}
              ${_row('Département', deptLabel)}
              ${_row('Technicien assigné', technician_name, BLEU)}
              ${_row('N° incident', issue_id)}
            </table>
          </div>
          ${_footer}
        </div>
      `;
      const textContent = `Incident critique pris en charge\nÉquipement: ${equipLabel}\nTechnicien: ${technician_name || '—'}\nN° incident: ${issue_id || '—'}`;
      return { subject, htmlContent, textContent };
    }

    // ── Superviseur : diagnostic posé sur un incident critique ────────────────
    case 'critical_diagnosed': {
      const subject = `🔍 [CRITIQUE] Diagnostic posé — ${equipLabel}`;
      const htmlContent = `
        <div style="font-family:Arial,sans-serif;max-width:600px;color:#212121">
          <div style="background:${BLEU};padding:16px 24px;border-radius:6px 6px 0 0">
            <h2 style="color:#fff;margin:0;font-size:18px">🔍 Diagnostic posé sur un incident critique</h2>
          </div>
          <div style="border:1px solid #e0e0e0;border-top:none;border-radius:0 0 6px 6px;padding:20px 24px">
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;width:100%">
              ${_row('Équipement', `<strong>${equipLabel}</strong>`)}
              ${_row('Département', deptLabel)}
              ${_row('Technicien', technician_name)}
              ${_row('N° incident', issue_id)}
            </table>
            <div style="margin-top:16px;padding:14px;background:#E3F2FD;border-radius:4px;border-left:4px solid ${BLEU}">
              <p style="margin:0 0 6px;font-size:12px;color:${GRIS};text-transform:uppercase;letter-spacing:.5px">Diagnostic</p>
              <p style="margin:0;font-size:14px">${diagnosis || '—'}</p>
            </div>
          </div>
          ${_footer}
        </div>
      `;
      const textContent = `Diagnostic posé\nÉquipement: ${equipLabel}\nTechnicien: ${technician_name || '—'}\nDiagnostic: ${diagnosis || '—'}\nN° incident: ${issue_id || '—'}`;
      return { subject, htmlContent, textContent };
    }

    // ── Superviseur : incident critique résolu — avec KPIs complets ───────────
    case 'critical_resolved': {
      // Calcul du temps de résolution
      let resolutionTimeStr = '—';
      if (created_at && resolved_at) {
        try {
          const ms = new Date(resolved_at).getTime() - new Date(created_at).getTime();
          resolutionTimeStr = _formatDuration(ms);
        } catch (_) {}
      }

      const subject = `✅ [CRITIQUE] Résolu — ${equipLabel} (${resolutionTimeStr})`;
      const htmlContent = `
        <div style="font-family:Arial,sans-serif;max-width:600px;color:#212121">
          <div style="background:${VERT};padding:16px 24px;border-radius:6px 6px 0 0">
            <h2 style="color:#fff;margin:0;font-size:18px">✅ Incident critique résolu</h2>
          </div>
          <div style="border:1px solid #e0e0e0;border-top:none;border-radius:0 0 6px 6px;padding:20px 24px">

            <!-- Résumé -->
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;width:100%">
              ${_row('Équipement', `<strong>${equipLabel}</strong>`)}
              ${_row('Département', deptLabel)}
              ${_row('Technicien', technician_name)}
              ${_row('N° incident', issue_id)}
            </table>

            <!-- KPIs de résolution -->
            <h3 style="font-size:14px;color:${GRIS};text-transform:uppercase;letter-spacing:.5px;margin:20px 0 8px;border-bottom:1px solid #e0e0e0;padding-bottom:8px">
              Indicateurs de résolution (KPIs)
            </h3>
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;width:100%">
              ${_row('Délai de résolution', `<strong>${resolutionTimeStr}</strong>`, VERT)}
              ${_row('Diagnostic (cause)', diagnosis || 'Non renseigné')}
              ${_row('Actions correctives', actions  || 'Non renseignées')}
              ${_row('Pièces remplacées',  parts_replaced || 'Aucune')}
            </table>

            <div style="margin-top:20px;padding:12px;background:#E8F5E9;border-radius:4px;border-left:4px solid ${VERT}">
              <p style="margin:0;font-size:13px;color:${VERT}">
                <strong>Incident clôturé.</strong> L'équipement est de nouveau opérationnel.
              </p>
            </div>
          </div>
          ${_footer}
        </div>
      `;
      const textContent = [
        `Incident critique RÉSOLU — ${equipLabel}`,
        `Département: ${deptLabel}`,
        `Technicien: ${technician_name || '—'}`,
        `Délai de résolution: ${resolutionTimeStr}`,
        `Diagnostic: ${diagnosis || '—'}`,
        `Actions: ${actions || '—'}`,
        `Pièces: ${parts_replaced || '—'}`,
        `N° incident: ${issue_id || '—'}`,
      ].join('\n');
      return { subject, htmlContent, textContent };
    }

    // ── Superviseur / Admin : rapport KPI mensuel (cron db-service) ───────────
    case 'monthly_report': {
      const {
        month_label,
        issues_created,
        issues_resolved,
        issues_still_open,
        by_urgency,
        mttr_hours,
        pm_compliance_pct,
        equipment_out_of_service,
        top_equipment,
      } = payload;

      const monthLabel = month_label || 'mois écoulé';
      // Aucune division ici : mttr_hours est déjà calculé côté db-service,
      // null signifie « aucun incident résolu ce mois » → afficher un tiret.
      const mttrStr = (mttr_hours === null || mttr_hours === undefined) ? '—' : `${mttr_hours} h`;
      const pmStr   = (pm_compliance_pct === null || pm_compliance_pct === undefined) ? '—' : `${pm_compliance_pct} %`;

      // Répartition par urgence : ligne compacte "Critique : 3 · Urgent : 10 · …"
      const urgencyStr = by_urgency && Object.keys(by_urgency).length > 0
        ? Object.entries(by_urgency).map(([k, v]) => `${k} : ${v}`).join(' · ')
        : '—';

      // Top équipements du mois (max 3, calculé côté db-service)
      const topRows = Array.isArray(top_equipment) && top_equipment.length > 0
        ? top_equipment.map((e, i) => _row(`${i + 1}. ${e.name || '—'}`, `${e.count} incident(s)`)).join('')
        : _row('Aucun', '—');

      const subject = `📊 Rapport mensuel GMAO — ${monthLabel}`;
      const htmlContent = `
        <div style="font-family:Arial,sans-serif;max-width:600px;color:#212121">
          <div style="background:${BLEU};padding:16px 24px;border-radius:6px 6px 0 0">
            <h2 style="color:#fff;margin:0;font-size:18px">📊 Rapport mensuel GMAO — ${monthLabel}</h2>
          </div>
          <div style="border:1px solid #e0e0e0;border-top:none;border-radius:0 0 6px 6px;padding:20px 24px">
            <p style="margin:0 0 16px;font-size:14px;color:${GRIS}">
              Synthèse des indicateurs de maintenance de l'hôpital pour <strong>${monthLabel}</strong>.
            </p>

            <h3 style="font-size:14px;color:${GRIS};text-transform:uppercase;letter-spacing:.5px;margin:0 0 8px;border-bottom:1px solid #e0e0e0;padding-bottom:8px">
              Incidents
            </h3>
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;width:100%">
              ${_row('Incidents signalés', `<strong>${issues_created ?? 0}</strong>`)}
              ${_row('Incidents résolus', `<strong>${issues_resolved ?? 0}</strong>`, VERT)}
              ${_row('Incidents encore ouverts', `${issues_still_open ?? 0}`, ORANGE)}
              ${_row('Répartition par urgence', urgencyStr)}
              ${_row('MTTR (délai moyen de résolution)', `<strong>${mttrStr}</strong>`)}
            </table>

            <h3 style="font-size:14px;color:${GRIS};text-transform:uppercase;letter-spacing:.5px;margin:20px 0 8px;border-bottom:1px solid #e0e0e0;padding-bottom:8px">
              Parc & maintenance préventive
            </h3>
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;width:100%">
              ${_row('Conformité maintenance préventive', `<strong>${pmStr}</strong>`)}
              ${_row('Équipements hors service', `${equipment_out_of_service ?? 0}`, ROUGE)}
            </table>

            <h3 style="font-size:14px;color:${GRIS};text-transform:uppercase;letter-spacing:.5px;margin:20px 0 8px;border-bottom:1px solid #e0e0e0;padding-bottom:8px">
              Équipements les plus signalés
            </h3>
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;width:100%">
              ${topRows}
            </table>

            <div style="margin-top:20px;padding:12px;background:#E3F2FD;border-radius:4px;border-left:4px solid ${BLEU}">
              <p style="margin:0;font-size:13px;color:${BLEU}">
                Le détail complet est disponible dans les écrans <strong>Rapports</strong> et <strong>Analytique</strong> de l'application GMAO.
              </p>
            </div>
          </div>
          ${_footer}
        </div>
      `;
      const textContent = [
        `Rapport mensuel GMAO — ${monthLabel}`,
        `Incidents signalés: ${issues_created ?? 0}`,
        `Incidents résolus: ${issues_resolved ?? 0}`,
        `Incidents encore ouverts: ${issues_still_open ?? 0}`,
        `Répartition par urgence: ${urgencyStr}`,
        `MTTR: ${mttrStr}`,
        `Conformité PM: ${pmStr}`,
        `Équipements hors service: ${equipment_out_of_service ?? 0}`,
      ].join('\n');
      return { subject, htmlContent, textContent };
    }

    // ── Technicien / Admin : maintenance préventive à planifier ───────────────
    case 'pm_due': {
      const subject = `🔧 [PM] Maintenance préventive à planifier — ${equipLabel}`;
      const htmlContent = `
        <div style="font-family:Arial,sans-serif;max-width:600px;color:#212121">
          <div style="background:${ORANGE};padding:16px 24px;border-radius:6px 6px 0 0">
            <h2 style="color:#fff;margin:0;font-size:18px">🔧 Maintenance préventive à planifier</h2>
          </div>
          <div style="border:1px solid #e0e0e0;border-top:none;border-radius:0 0 6px 6px;padding:20px 24px">
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;width:100%">
              ${_row('Équipement', `<strong>${equipLabel}</strong>`)}
              ${_row('Département', deptLabel)}
            </table>
          </div>
          ${_footer}
        </div>
      `;
      const textContent = `Maintenance préventive à planifier\nÉquipement: ${equipLabel}\nDépartement: ${deptLabel}`;
      return { subject, htmlContent, textContent };
    }

    default:
      return null;
  }
}

module.exports = { sendEmail, buildEmailContent };
