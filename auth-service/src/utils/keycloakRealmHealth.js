// ── Auto-réparation du realm Keycloak (dérive verifyEmail) ────────────────────
// verifyEmail doit toujours rester false (vérification email informative,
// jamais bloquante — décision produit). Ce contrôle corrige la dérive au
// démarrage si configure-realm.sh a échoué silencieusement (`|| true` Jenkins).

'use strict';

const { kcAdminFetch } = require('./keycloakAdmin');

async function checkAndFixVerifyEmailFlag() {
  try {
    const getResp = await kcAdminFetch('');
    if (!getResp.ok) {
      console.warn(`[AUTH] Vérification du realm Keycloak impossible : ${getResp.status}`);
      return;
    }
    const realm = await getResp.json();

    // Seul verifyEmail === true déclenche une correction. undefined/false =
    // conforme, aucun appel PUT (on ne réécrit jamais le realm sur une
    // hypothèse non vérifiée).
    if (realm.verifyEmail !== true) {
      return;
    }

    console.warn('[AUTH] Dérive détectée : realm.verifyEmail=true (devrait être false) — correction automatique en cours.');
    const putResp = await kcAdminFetch('', {
      method: 'PUT',
      body: JSON.stringify({ ...realm, verifyEmail: false }),
    });
    if (!putResp.ok) {
      console.error(`[AUTH] Échec de la correction automatique du realm : ${putResp.status}`);
      return;
    }
    console.log('[AUTH] realm.verifyEmail corrigé à false avec succès.');
  } catch (err) {
    console.error(`[AUTH] Erreur inattendue lors de la vérification du realm Keycloak : ${err.message}`);
  }
}

module.exports = { checkAndFixVerifyEmailFlag };
