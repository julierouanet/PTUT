// ── Plan de remplacement biomédical (RA3 S5) ────────────────────────────────
// Logique de calcul PURE (sans accès DB) du statut de remplacement et de
// l'horizon budgétaire d'un équipement. Source de vérité unique, testable.
//
// Règles (voir prompt RA3 S5) :
//   age      = annéeCourante − manuf_year ; fallback annéeCourante − année(install_date).
//   lifespan = expected_lifespan_years de la sous-catégorie (NULL = non défini).
//   statut de remplacement :
//     • "donnee_manquante" si lifespan NULL (ou age inconnu)  → non noté, pas d'horizon.
//     • "a_remplacer"      si age >= lifespan OU status == 'To be disposal'.
//     • "bientot"          si 0.8*lifespan <= age < lifespan.
//     • "ok"               sinon.
//   horizon (seulement si statut noté) :
//     reste = lifespan − age
//     • "cette_annee" si reste <= 0 OU status == 'To be disposal'.
//     • "1_2_ans"     si 0 < reste <= 2.
//     • "plus_tard"   si reste > 2.
//
// IMPORTANT : warranty_end_date n'intervient PAS ; 'Out of service' ne déclenche
// PAS "a_remplacer". Seuls age>=lifespan et 'To be disposal' déclenchent.

const TO_BE_DISPOSAL = 'To be disposal';

// Calcule l'âge (en années) d'un équipement. Retourne null si indéterminable.
function computeAge(manufYear, installDate, currentYear) {
  const year = Number(currentYear);
  if (Number.isInteger(manufYear) && manufYear > 0) {
    return year - manufYear;
  }
  if (installDate) {
    const y = new Date(installDate).getFullYear();
    if (Number.isFinite(y)) return year - y;
  }
  return null;
}

// Calcule { status_replacement, horizon, overshoot } à partir de l'âge, de la
// durée de vie de référence et du statut courant de l'équipement.
function computeReplacement({ age, lifespan, status }) {
  // Donnée manquante : pas de durée de vie ou âge indéterminable → non noté.
  if (lifespan === null || lifespan === undefined || age === null || age === undefined) {
    return { status_replacement: 'donnee_manquante', horizon: null, overshoot: null };
  }

  const toBeDisposal = status === TO_BE_DISPOSAL;

  let statusReplacement;
  if (age >= lifespan || toBeDisposal) {
    statusReplacement = 'a_remplacer';
  } else if (age >= 0.8 * lifespan) {
    statusReplacement = 'bientot';
  } else {
    statusReplacement = 'ok';
  }

  const reste = lifespan - age;
  let horizon;
  if (reste <= 0 || toBeDisposal) {
    horizon = 'cette_annee';
  } else if (reste <= 2) {
    horizon = '1_2_ans';
  } else {
    horizon = 'plus_tard';
  }

  return { status_replacement: statusReplacement, horizon, overshoot: age - lifespan };
}

// Rang de tri par criticité : A (0) > B (1) > C (2) > inconnu (3).
function criticalityRank(criticality) {
  switch (criticality) {
    case 'A': return 0;
    case 'B': return 1;
    case 'C': return 2;
    default:  return 3;
  }
}

// Construit le plan complet { summary, items } à partir des lignes d'équipement
// biomédical (chaque ligne : id, name, subcategory, criticality, manuf_year,
// install_date, status, expected_lifespan_years).
function buildReplacementPlan(rows, currentYear) {
  const items = rows.map((r) => {
    const age = computeAge(r.manuf_year, r.install_date, currentYear);
    const lifespan = (r.expected_lifespan_years === null || r.expected_lifespan_years === undefined)
      ? null
      : Number(r.expected_lifespan_years);
    const { status_replacement, horizon, overshoot } = computeReplacement({
      age, lifespan, status: r.status,
    });
    return {
      id: r.id,
      name: r.name,
      subcategory: r.subcategory ?? null,
      criticality: r.criticality ?? null,
      age,
      lifespan,
      overshoot,
      status_replacement,
      horizon,
    };
  });

  // Tri : criticité A > B > C, puis dépassement (overshoot) décroissant.
  // Les "donnee_manquante" (overshoot null) sont rejetés en fin de liste.
  items.sort((a, b) => {
    const rc = criticalityRank(a.criticality) - criticalityRank(b.criticality);
    if (rc !== 0) return rc;
    const oa = a.overshoot === null ? Number.NEGATIVE_INFINITY : a.overshoot;
    const ob = b.overshoot === null ? Number.NEGATIVE_INFINITY : b.overshoot;
    return ob - oa;
  });

  // Agrégats.
  const byHorizon = { cette_annee: 0, '1_2_ans': 0, plus_tard: 0, donnee_manquante: 0 };
  const byCriticality = { A: 0, B: 0, C: 0 };
  let endOfLifeCount = 0;
  let ageSum = 0;
  let ageCount = 0;

  for (const it of items) {
    if (it.status_replacement === 'donnee_manquante') {
      byHorizon.donnee_manquante += 1;
    } else if (it.horizon && byHorizon[it.horizon] !== undefined) {
      byHorizon[it.horizon] += 1;
    }
    if (it.status_replacement === 'a_remplacer') endOfLifeCount += 1;
    if (it.criticality && byCriticality[it.criticality] !== undefined) {
      byCriticality[it.criticality] += 1;
    }
    if (it.age !== null && it.age !== undefined) {
      ageSum += it.age;
      ageCount += 1;
    }
  }

  const biomedicalCount = items.length;
  const avgAge = ageCount > 0 ? Math.round((ageSum / ageCount) * 10) / 10 : 0;
  const endOfLifePct = biomedicalCount > 0
    ? Math.round((endOfLifeCount / biomedicalCount) * 1000) / 10
    : 0;

  return {
    summary: {
      biomedical_count: biomedicalCount,
      avg_age_years: avgAge,
      end_of_life_count: endOfLifeCount,
      end_of_life_pct: endOfLifePct,
      by_horizon: byHorizon,
      by_criticality: byCriticality,
    },
    items,
  };
}

module.exports = { computeAge, computeReplacement, criticalityRank, buildReplacementPlan };
