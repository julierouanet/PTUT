// ── Service d'envoi d'emails via l'API REST Brevo ─────────────────────────────
// Utilisé pour les notifications applicatives centrées sur les incidents CRITIQUES.
// Distinct du SMTP Keycloak utilisé pour reset/vérification de compte.

'use strict';

const { BREVO_API_KEY, BREVO_SENDER_EMAIL, BREVO_SENDER_NAME } = require('../config');

const BREVO_SMTP_URL = 'https://api.brevo.com/v3/smtp/email';

// ── Utilitaires ────────────────────────────────────────────────────────────────

const ROUGE  = '#D32F2F';
const ORANGE = '#F57C00';
const VERT   = '#388E3C';
const BLEU   = '#1565C0';
const GRIS   = '#757575';

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
  if (!BREVO_API_KEY) {
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
        'api-key':      BREVO_API_KEY,
        'Content-Type': 'application/json',
        'Accept':       'application/json',
      },
      body: JSON.stringify({
        sender:      { email: BREVO_SENDER_EMAIL, name: BREVO_SENDER_NAME },
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
 *   critical_new_issue    → techniciens : nouvel incident critique
 *   critical_acknowledged → superviseurs : technicien a pris en charge
 *   critical_diagnosed    → superviseurs : diagnostic posé
 *   critical_resolved     → superviseurs : incident résolu (KPIs)
 *   pm_due                → techniciens/admins : maintenance préventive à planifier
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

    // ── Technicien : nouvel incident CRITIQUE signalé ──────────────────────────
    case 'critical_new_issue': {
      const subject = `🚨 [CRITIQUE] Nouvel incident — ${equipLabel} · ${deptLabel}`;
      const htmlContent = `
        <div style="font-family:Arial,sans-serif;max-width:600px;color:#212121">
          <div style="background:${ROUGE};padding:16px 24px;border-radius:6px 6px 0 0">
            <h2 style="color:#fff;margin:0;font-size:18px">🚨 Incident CRITIQUE signalé</h2>
          </div>
          <div style="border:1px solid #e0e0e0;border-top:none;border-radius:0 0 6px 6px;padding:20px 24px">
            <p style="margin:0 0 16px;font-size:14px;color:${GRIS}">
              Un incident de niveau <strong style="color:${ROUGE}">Critique</strong> vient d'être signalé dans votre groupe technique.
              Votre intervention est requise en priorité.
            </p>
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;width:100%">
              ${_row('Équipement', `<strong>${equipLabel}</strong>`)}
              ${_row('Département', deptLabel)}
              ${_row('Description', description ? description.substring(0, 200) : null)}
              ${_row('Signalé par', reporter_name)}
              ${_row('N° incident', issue_id)}
            </table>
            <div style="margin-top:20px;padding:12px;background:#FFEBEE;border-radius:4px;border-left:4px solid ${ROUGE}">
              <p style="margin:0;font-size:13px;color:${ROUGE}"><strong>Action requise :</strong> Prenez en charge cet incident dès que possible via l'application GMAO.</p>
            </div>
          </div>
          ${_footer}
        </div>
      `;
      const textContent = `INCIDENT CRITIQUE - ${equipLabel} (${deptLabel})\nSignalé par: ${reporter_name || '—'}\nDescription: ${description || '—'}\nN° incident: ${issue_id || '—'}`;
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
