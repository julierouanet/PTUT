const N = require('../scripts/lib/inventory_normalizer');

describe('cleanCell', () => {
  test('null/undefined → null', () => {
    expect(N.cleanCell(null)).toBeNull();
    expect(N.cleanCell(undefined)).toBeNull();
  });

  test('chaîne vide ou espaces → null', () => {
    expect(N.cleanCell('')).toBeNull();
    expect(N.cleanCell('   ')).toBeNull();
  });

  test('marqueurs "absent" du XLSX → null', () => {
    for (const v of ['n/a', 'N/A', 'na', 'NA', 'unknown', 'UKNOWN', 'Unknown', 'none', 'NONE', '-']) {
      expect(N.cleanCell(v)).toBeNull();
    }
  });

  test('valeur valide trim → string', () => {
    expect(N.cleanCell('  Philips  ')).toBe('Philips');
    expect(N.cleanCell(989806)).toBe('989806');
  });
});

describe('normalizeStatus', () => {
  test('variantes operational → "En service"', () => {
    for (const v of ['operational', 'Operational', 'OPERATIONAL', 'opeational']) {
      expect(N.normalizeStatus(v)).toBe('En service');
    }
  });

  test('variantes UNDER M → "En maintenance"', () => {
    for (const v of ['UNDER M', 'UNDERM', 'under m', 'Under M']) {
      expect(N.normalizeStatus(v)).toBe('En maintenance');
    }
  });

  test('variantes IDDLE → "Inactif"', () => {
    for (const v of ['IDDLE', 'iddle', 'IDDLE GO TO RBC', 'Iddle']) {
      expect(N.normalizeStatus(v)).toBe('Inactif');
    }
  });

  test('DISPOSED → "Hors service"', () => {
    expect(N.normalizeStatus('DISPOSED')).toBe('Hors service');
    expect(N.normalizeStatus('disposed')).toBe('Hors service');
  });

  test('to be disposal → "À éliminer"', () => {
    expect(N.normalizeStatus('to be disposal')).toBe('À éliminer');
    expect(N.normalizeStatus('To be disposal')).toBe('À éliminer');
  });

  test('KIBIRIZI DH → "Transféré"', () => {
    expect(N.normalizeStatus('KIBIRIZI DH')).toBe('Transféré');
  });

  test('null/vide → "Disponible" (défaut sûr)', () => {
    expect(N.normalizeStatus(null)).toBe('Disponible');
    expect(N.normalizeStatus('')).toBe('Disponible');
    expect(N.normalizeStatus('   ')).toBe('Disponible');
  });

  test('valeur inconnue → "Disponible"', () => {
    expect(N.normalizeStatus('foobar')).toBe('Disponible');
  });
});

describe('normalizeRefName', () => {
  test('supprime tabulations et espaces en début/fin', () => {
    expect(N.normalizeRefName('\tPavillon General')).toBe('Pavillon General');
    expect(N.normalizeRefName('  Internal Medicine  ')).toBe('Internal Medicine');
  });

  test('normalise les espaces internes', () => {
    expect(N.normalizeRefName('Internal   Medicine')).toBe('Internal Medicine');
  });

  test('null/vide → null', () => {
    expect(N.normalizeRefName(null)).toBeNull();
    expect(N.normalizeRefName('')).toBeNull();
    expect(N.normalizeRefName('   ')).toBeNull();
  });
});

describe('normalizeDate', () => {
  test('Date JS → ISO YYYY-MM-DD', () => {
    expect(N.normalizeDate(new Date(Date.UTC(2023, 3, 5)))).toBe('2023-04-05');
  });

  test('entier année (2023) → 2023-01-01', () => {
    expect(N.normalizeDate(2023)).toBe('2023-01-01');
    expect(N.normalizeDate(2014)).toBe('2014-01-01');
  });

  test('chaîne DD/MM/YYYY → ISO', () => {
    expect(N.normalizeDate('24/2/2025')).toBe('2025-02-24');
    expect(N.normalizeDate('18/3/2022')).toBe('2022-03-18');
    expect(N.normalizeDate('05/12/2024')).toBe('2024-12-05');
  });

  test('chaîne ISO déjà → normalisée', () => {
    expect(N.normalizeDate('2024-01-01')).toBe('2024-01-01');
    expect(N.normalizeDate('2024-1-5')).toBe('2024-01-05');
  });

  test('année seule en string → 2022-01-01', () => {
    expect(N.normalizeDate('2022')).toBe('2022-01-01');
  });

  test('marqueurs absents → null', () => {
    expect(N.normalizeDate(null)).toBeNull();
    expect(N.normalizeDate('n/a')).toBeNull();
    expect(N.normalizeDate('UKNOWN')).toBeNull();
  });
});

describe('normalizeYear', () => {
  test('Date JS → année', () => {
    expect(N.normalizeYear(new Date(Date.UTC(2023, 3, 5)))).toBe(2023);
  });

  test('entier 2023 → 2023', () => {
    expect(N.normalizeYear(2023)).toBe(2023);
  });

  test('chaîne "18/3/2022" → 2022', () => {
    expect(N.normalizeYear('18/3/2022')).toBe(2022);
  });

  test('chaîne "2022" → 2022', () => {
    expect(N.normalizeYear('2022')).toBe(2022);
  });

  test('null / vide / n-a → null', () => {
    expect(N.normalizeYear(null)).toBeNull();
    expect(N.normalizeYear('')).toBeNull();
    expect(N.normalizeYear('N/A')).toBeNull();
  });
});

describe('serialToId', () => {
  test('serial valide → slug minuscule', () => {
    expect(N.serialToId('CBB0123180183', 1)).toBe('cbb0123180183');
    expect(N.serialToId('M766ASO991030', 2)).toBe('m766aso991030');
  });

  test('serial avec caractères spéciaux → tirets', () => {
    expect(N.serialToId('J201906267/200079781411', 3)).toBe('j201906267-200079781411');
    expect(N.serialToId('A0150 200406', 4)).toBe('a0150-200406');
  });

  test('serial vide / null → noserial-NNN', () => {
    expect(N.serialToId(null, 1)).toBe('noserial-001');
    expect(N.serialToId('', 12)).toBe('noserial-012');
    expect(N.serialToId('n/a', 99)).toBe('noserial-099');
  });

  test('serial uniquement des caractères spéciaux → noserial-NNN', () => {
    expect(N.serialToId('///', 7)).toBe('noserial-007');
  });

  test('id généré valide pour la regex de routes/equipment.js', () => {
    const re = /^[a-zA-Z0-9_-]+$/;
    expect(re.test(N.serialToId('CBB0123180183', 1))).toBe(true);
    expect(re.test(N.serialToId(null, 1))).toBe(true);
    expect(re.test(N.serialToId('J201906267/200079781411', 1))).toBe(true);
  });
});
