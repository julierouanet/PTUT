// ── Service d'envoi d'emails via l'API REST Brevo ─────────────────────────────
// Utilisé pour les notifications applicatives (incidents, PM).
// Distinct du SMTP Keycloak utilisé pour reset/vérification de compte.

'use strict';

const { BREVO_API_KEY, BREVO_SENDER_EMAIL, BREVO_SENDER_NAME } = require('../config');

const BREVO_SMTP_URL = 'https://api.brevo.com/v3/smtp/email';

/**
 * Envoie un email transactionnel via l'API Brevo.
 * Fire-and-forget : ne lève pas d'exception — loggue les erreurs uniquement.
 *
 * @param {object} params
 * @param {string} params.to          - Adresse email du destinataire
 * @param {string} [params.toName]    - Nom du destinataire
 * @param {string} params.subject     - Sujet de l'email
 * @param {string} params.htmlContent - Corps HTML
 * @param {string} [params.textContent] - Corps texte brut (fallback)
 */
async function sendEmail({ to, toName, subject, htmlContent, textContent }) {
  if (!BREVO_API_KEY) {
    console.warn('[EMAIL] BREVO_API_KEY absent — email non envoyé à', to);
    return;
  }
  if (!to || !subject) {
    console.warn('[EMAIL] Paramètres manquants (to/subject) — email ignoré');
    return;
  }

  try {
    const resp = await fetch(BREVO_SMTP_URL, {
      method: 'POST',
      headers: {
        'api-key':     BREVO_API_KEY,
        'Content-Type':'application/json',
        'Accept':      'application/json',
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
      console.error(`[EMAIL] Erreur Brevo ${resp.status} → ${to}: ${txt.substring(0, 200)}`);
    } else {
      console.log(`[EMAIL] Envoyé à ${to} — "${subject}"`);
    }
  } catch (err) {
    console.error(`[EMAIL] Exception envoi → ${to}: ${err.message}`);
  }
}

/**
 * Construit le contenu HTML + texte d'un email selon le type d'événement.
 *
 * @param {'new_issue'|'issue_assigned'|'issue_resolved'|'issue_status_update'|'pm_due'} type
 * @param {object} payload - Données de l'événement (issue_id, equipment_name, department, etc.)
 * @returns {{ subject: string, htmlContent: string, textContent: string } | null}
 */
function buildEmailContent(type, payload = {}) {
  const {
    issue_id,
    equipment_name,
    department,
    urgency,
    reporter_name,
    new_status,
    tech_name,
  } = payload;

  const footer = `<hr style="margin-top:24px"><p style="color:#888;font-size:12px">GMAO — Hôpital de District de Kabutare</p>`;
  const equipLabel  = equipment_name || 'Non spécifié';
  const deptLabel   = department     || '—';
  const urgLabel    = urgency        || 'Moyen';

  switch (type) {
    case 'new_issue':
      return {
        subject: `[GMAO] Nouvel incident — ${equipLabel} (${urgLabel})`,
        htmlContent: `
          <h2 style="color:#1976D2">Nouvel incident signalé</h2>
          <table cellpadding="6" style="border-collapse:collapse">
            <tr><td><strong>Équipement :</strong></td><td>${equipLabel}</td></tr>
            <tr><td><strong>Département :</strong></td><td>${deptLabel}</td></tr>
            <tr><td><strong>Urgence :</strong></td><td style="color:${urgLabel==='Critique'?'#d32f2f':urgLabel==='Urgent'?'#f57c00':'#333'}">${urgLabel}</td></tr>
            <tr><td><strong>Signalé par :</strong></td><td>${reporter_name || '—'}</td></tr>
            <tr><td><strong>ID incident :</strong></td><td>${issue_id || '—'}</td></tr>
          </table>
          ${footer}
        `,
        textContent: `Nouvel incident signalé\nÉquipement: ${equipLabel}\nDépartement: ${deptLabel}\nUrgence: ${urgLabel}\nSignalé par: ${reporter_name || '—'}`,
      };

    case 'issue_assigned':
      return {
        subject: `[GMAO] Incident assigné — ${equipLabel}`,
        htmlContent: `
          <h2 style="color:#1976D2">Un incident vous a été assigné</h2>
          <table cellpadding="6" style="border-collapse:collapse">
            <tr><td><strong>Équipement :</strong></td><td>${equipLabel}</td></tr>
            <tr><td><strong>Département :</strong></td><td>${deptLabel}</td></tr>
            <tr><td><strong>Urgence :</strong></td><td>${urgLabel}</td></tr>
            <tr><td><strong>ID incident :</strong></td><td>${issue_id || '—'}</td></tr>
          </table>
          ${footer}
        `,
        textContent: `Un incident vous a été assigné\nÉquipement: ${equipLabel}\nDépartement: ${deptLabel}\nUrgence: ${urgLabel}`,
      };

    case 'issue_resolved':
      return {
        subject: `[GMAO] Votre incident a été résolu — ${equipLabel}`,
        htmlContent: `
          <h2 style="color:#388E3C">Votre incident a été résolu ✓</h2>
          <table cellpadding="6" style="border-collapse:collapse">
            <tr><td><strong>Équipement :</strong></td><td>${equipLabel}</td></tr>
            <tr><td><strong>Département :</strong></td><td>${deptLabel}</td></tr>
            <tr><td><strong>Technicien :</strong></td><td>${tech_name || '—'}</td></tr>
            <tr><td><strong>ID incident :</strong></td><td>${issue_id || '—'}</td></tr>
          </table>
          ${footer}
        `,
        textContent: `Votre incident a été résolu\nÉquipement: ${equipLabel}\nTechnicien: ${tech_name || '—'}`,
      };

    case 'issue_status_update':
      return {
        subject: `[GMAO] Mise à jour de votre incident — ${equipLabel}`,
        htmlContent: `
          <h2 style="color:#1976D2">Mise à jour de votre incident</h2>
          <table cellpadding="6" style="border-collapse:collapse">
            <tr><td><strong>Équipement :</strong></td><td>${equipLabel}</td></tr>
            <tr><td><strong>Département :</strong></td><td>${deptLabel}</td></tr>
            <tr><td><strong>Nouveau statut :</strong></td><td><strong>${new_status || '—'}</strong></td></tr>
            <tr><td><strong>ID incident :</strong></td><td>${issue_id || '—'}</td></tr>
          </table>
          ${footer}
        `,
        textContent: `Mise à jour de votre incident\nÉquipement: ${equipLabel}\nNouveau statut: ${new_status || '—'}`,
      };

    case 'pm_due':
      return {
        subject: `[GMAO] Maintenance préventive à planifier — ${equipLabel}`,
        htmlContent: `
          <h2 style="color:#F57C00">Maintenance préventive à planifier</h2>
          <table cellpadding="6" style="border-collapse:collapse">
            <tr><td><strong>Équipement :</strong></td><td>${equipLabel}</td></tr>
            <tr><td><strong>Département :</strong></td><td>${deptLabel}</td></tr>
          </table>
          ${footer}
        `,
        textContent: `Maintenance préventive à planifier\nÉquipement: ${equipLabel}\nDépartement: ${deptLabel}`,
      };

    default:
      return null;
  }
}

module.exports = { sendEmail, buildEmailContent };
