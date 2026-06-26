// ── Seuils d'urgence — source unique pour auth-service ────────────────────────
// Même valeurs/ordre que db-service/src/routes/issues.js VALID_URGENCIES.
// Pas de module partagé possible entre services (processus/bases séparés) :
// à maintenir manuellement en cohérence avec db-service en cas d'évolution.

'use strict';

const URGENCY_ORDER = ['Faible', 'Moyen', 'Urgent', 'Critique'];

const isValidUrgency = (v) => URGENCY_ORDER.includes(v);
const urgencyIndex    = (v) => URGENCY_ORDER.indexOf(v);

module.exports = { URGENCY_ORDER, isValidUrgency, urgencyIndex };
