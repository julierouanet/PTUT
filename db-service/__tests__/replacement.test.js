'use strict';

// Tests de la logique PURE du plan de remplacement biomédical (RA3 S5).
// Aucun accès DB : on teste computeAge / computeReplacement / buildReplacementPlan.

const {
  computeAge,
  computeReplacement,
  criticalityRank,
  buildReplacementPlan,
} = require('../src/utils/replacement');

const CURRENT_YEAR = 2026;

describe('computeAge', () => {
  test('utilise manuf_year en priorité', () => {
    expect(computeAge(2015, '2020-01-01', CURRENT_YEAR)).toBe(11);
  });

  test('fallback sur install_date si manuf_year absent', () => {
    expect(computeAge(null, '2020-06-15', CURRENT_YEAR)).toBe(6);
  });

  test('retourne null si aucune donnée de date', () => {
    expect(computeAge(null, null, CURRENT_YEAR)).toBeNull();
    expect(computeAge(0, null, CURRENT_YEAR)).toBeNull();
  });
});

describe('computeReplacement — statut & horizon', () => {
  test('équipement 11 ans / réf 10 ans → a_remplacer, cette_annee', () => {
    const r = computeReplacement({ age: 11, lifespan: 10, status: 'Operational' });
    expect(r.status_replacement).toBe('a_remplacer');
    expect(r.horizon).toBe('cette_annee');
    expect(r.overshoot).toBe(1);
  });

  test('équipement 9 ans / réf 10 ans → bientot, 1_2_ans', () => {
    const r = computeReplacement({ age: 9, lifespan: 10, status: 'Operational' });
    expect(r.status_replacement).toBe('bientot');
    expect(r.horizon).toBe('1_2_ans');
  });

  test('équipement neuf 2 ans / réf 10 ans → ok, plus_tard', () => {
    const r = computeReplacement({ age: 2, lifespan: 10, status: 'Operational' });
    expect(r.status_replacement).toBe('ok');
    expect(r.horizon).toBe('plus_tard');
  });

  test('seuil bientot : exactement 0.8*lifespan (8/10) → bientot', () => {
    const r = computeReplacement({ age: 8, lifespan: 10, status: 'Operational' });
    expect(r.status_replacement).toBe('bientot');
  });

  test("status 'To be disposal' force a_remplacer + cette_annee même si jeune", () => {
    const r = computeReplacement({ age: 1, lifespan: 10, status: 'To be disposal' });
    expect(r.status_replacement).toBe('a_remplacer');
    expect(r.horizon).toBe('cette_annee');
  });

  test("'Out of service' NE déclenche PAS a_remplacer", () => {
    const r = computeReplacement({ age: 2, lifespan: 10, status: 'Out of service' });
    expect(r.status_replacement).toBe('ok');
  });

  test('lifespan NULL → donnee_manquante, pas d’horizon', () => {
    const r = computeReplacement({ age: 5, lifespan: null, status: 'Operational' });
    expect(r.status_replacement).toBe('donnee_manquante');
    expect(r.horizon).toBeNull();
    expect(r.overshoot).toBeNull();
  });

  test('age NULL (donnée manquante) → donnee_manquante', () => {
    const r = computeReplacement({ age: null, lifespan: 10, status: 'Operational' });
    expect(r.status_replacement).toBe('donnee_manquante');
    expect(r.horizon).toBeNull();
  });

  test('frontière reste == 2 → 1_2_ans', () => {
    const r = computeReplacement({ age: 8, lifespan: 10, status: 'Operational' });
    expect(r.horizon).toBe('1_2_ans');
  });
});

describe('criticalityRank', () => {
  test('A < B < C < inconnu', () => {
    expect(criticalityRank('A')).toBeLessThan(criticalityRank('B'));
    expect(criticalityRank('B')).toBeLessThan(criticalityRank('C'));
    expect(criticalityRank('C')).toBeLessThan(criticalityRank(null));
  });
});

describe('buildReplacementPlan — agrégats & tri', () => {
  const rows = [
    // A, 11 ans, réf 10 → a_remplacer / cette_annee, overshoot 1
    { id: 'eq-a', name: 'Echographe', subcategory: 'Echographe', criticality: 'A',
      manuf_year: 2015, install_date: null, status: 'Operational', expected_lifespan_years: 10 },
    // B, 9 ans, réf 10 → bientot / 1_2_ans
    { id: 'eq-b', name: 'Moniteur', subcategory: 'Monitoring', criticality: 'B',
      manuf_year: 2017, install_date: null, status: 'Operational', expected_lifespan_years: 10 },
    // C, 2 ans, réf 10 → ok / plus_tard
    { id: 'eq-c', name: 'Pousse-seringue', subcategory: 'Thérapeutique', criticality: 'C',
      manuf_year: 2024, install_date: null, status: 'Operational', expected_lifespan_years: 10 },
    // A, lifespan NULL → donnee_manquante
    { id: 'eq-d', name: 'Appareil mystère', subcategory: 'Autre', criticality: 'A',
      manuf_year: 2010, install_date: null, status: 'Operational', expected_lifespan_years: null },
  ];

  const plan = buildReplacementPlan(rows, CURRENT_YEAR);

  test('summary.biomedical_count compte tous les équipements', () => {
    expect(plan.summary.biomedical_count).toBe(4);
  });

  test('end_of_life_count compte les a_remplacer', () => {
    expect(plan.summary.end_of_life_count).toBe(1);
    expect(plan.summary.end_of_life_pct).toBe(25);
  });

  test('by_horizon exclut donnee_manquante des comptes notés', () => {
    expect(plan.summary.by_horizon).toEqual({
      cette_annee: 1, '1_2_ans': 1, plus_tard: 1, donnee_manquante: 1,
    });
  });

  test('by_criticality compte A/B/C', () => {
    expect(plan.summary.by_criticality).toEqual({ A: 2, B: 1, C: 1 });
  });

  test('tri : criticité A > B > C, overshoot décroissant dans chaque groupe', () => {
    // Groupe A : eq-a (overshoot 1) avant eq-d (donnee_manquante, overshoot null).
    // Puis B (eq-b), puis C (eq-c).
    expect(plan.items.map((i) => i.id)).toEqual(['eq-a', 'eq-d', 'eq-b', 'eq-c']);
  });

  test('avg_age_years moyenne les âges connus', () => {
    // âges : 11, 9, 2, 16 → moyenne 9.5
    expect(plan.summary.avg_age_years).toBe(9.5);
  });
});
