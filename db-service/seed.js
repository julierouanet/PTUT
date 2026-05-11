const { getDb, closeDb } = require('./src/database');

// ──────────────────────────────────────────────
// EQUIPMENT
// ──────────────────────────────────────────────
const equipment = [
  { id: 'eq-001', name: 'Serveur Dell PowerEdge R750',          department: 'Administration',                          category: "Équipement ICT",                  serial_number: 'SRV-DELL-2023-001', status: 'Operational',      manufacturer: 'Dell Technologies',       location: 'Administration, Salle serveur' },
  { id: 'eq-002', name: 'Switch Cisco Catalyst 9300',           department: 'Administration',                          category: "Équipement ICT",                  serial_number: 'NET-CSC-2023-001',  status: 'Operational',      manufacturer: 'Cisco Systems',           location: 'Administration, Salle réseau' },
  { id: 'eq-003', name: 'Tensiomètre électronique Omron',       department: 'OPD (Consultations externes)',            category: "Équipement biomédical",           serial_number: 'BP-OMR-2023-001',   status: 'Operational',    manufacturer: 'Omron Healthcare',        location: 'OPD, Salle de consultation 1' },
  { id: 'eq-004', name: 'PC HP ProDesk 400',                    department: 'OPD (Consultations externes)',            category: "Équipement ICT",                  serial_number: 'PC-HP-2023-OPD-001',status: 'Operational',      manufacturer: 'HP Inc.',                 location: 'OPD, Réception' },
  { id: 'eq-005', name: 'ECG 12 dérivations Philips',           department: 'Médecine interne',                        category: "Équipement biomédical",           serial_number: 'ECG-PHL-2022-001',  status: 'Operational',      manufacturer: 'Philips Healthcare',      location: 'Médecine interne, Salle examen' },
  { id: 'eq-006', name: 'Moniteur patient Dräger Infinity',     department: 'Médecine interne',                        category: "Équipement biomédical",           serial_number: 'MON-DRG-2023-001',  status: 'Operational',      manufacturer: 'Dräger Medical',          location: 'Médecine interne, Chambre 101' },
  { id: 'eq-007', name: 'Incubateur néonatal Atom',             department: 'Pédiatrie',                               category: "Équipement biomédical",           serial_number: 'INC-ATM-2022-001',  status: 'Operational',      manufacturer: 'Atom Medical',            location: 'Pédiatrie, Unité néonat' },
  { id: 'eq-008', name: 'Balance pèse-bébé électronique',       department: 'Pédiatrie',                               category: "Équipement biomédical",           serial_number: 'BAL-PED-2023-001',  status: 'Operational',    manufacturer: 'Seca',                    location: 'Pédiatrie, Salle pesée' },
  { id: 'eq-009', name: 'Défibrillateur Philips HeartStart',    department: 'Urgences',                                category: "Équipement biomédical",           serial_number: 'DEF-PHL-2023-001',  status: 'Operational',    manufacturer: 'Philips Healthcare',      location: 'Urgences, Chariot réa' },
  { id: 'eq-010', name: "Chariot d'urgence complet",            department: 'Urgences',                                category: "Équipement biomédical",           serial_number: 'CHR-URG-2022-001',  status: 'Operational',      manufacturer: 'Medical Supplies Rwanda', location: 'Urgences, Zone triage' },
  { id: 'eq-011', name: 'Générateur électrique 250kVA',         department: 'Urgences',                                category: "Équipement électrique",           serial_number: 'GEN-CAT-2021-001',  status: 'Operational',    manufacturer: 'Caterpillar',             location: 'Urgences, Zone technique' },
  { id: 'eq-012', name: 'Analyseur hématologie Sysmex XN-1000', department: 'Laboratoire',                             category: "Équipement biomédical",           serial_number: 'HEM-SYS-2023-001',  status: 'Operational',      manufacturer: 'Sysmex Corporation',      location: 'Laboratoire, Salle hémato' },
  { id: 'eq-013', name: 'Centrifugeuse Eppendorf 5430',         department: 'Laboratoire',                             category: "Équipement biomédical",           serial_number: 'CEN-EPP-2022-001',  status: 'Operational',      manufacturer: 'Eppendorf',               location: 'Laboratoire, Salle biochimie' },
  { id: 'eq-014', name: 'Microscope optique Olympus CX43',      department: 'Laboratoire',                             category: "Équipement biomédical",           serial_number: 'MIC-OLY-2023-001',  status: 'Operational',      manufacturer: 'Olympus',                 location: 'Laboratoire, Salle parasito' },
  { id: 'eq-015', name: 'Réfrigérateur réactifs Liebherr',      department: 'Laboratoire',                             category: "Équipement électrique",           serial_number: 'REF-LIE-2022-001',  status: 'Operational',      manufacturer: 'Liebherr',                location: 'Laboratoire, Stockage' },
  { id: 'eq-016', name: 'Fauteuil dentaire Planmeca',           department: 'Stomatologie',                            category: "Équipement biomédical",           serial_number: 'DEN-PLM-2022-001',  status: 'Operational',      manufacturer: 'Planmeca',                location: 'Stomatologie, Salle 1' },
  { id: 'eq-017', name: 'Radiographie dentaire panoramique',    department: 'Stomatologie',                            category: "Équipement biomédical",           serial_number: 'RAD-DEN-2021-001',  status: 'Operational',      manufacturer: 'Carestream Dental',       location: 'Stomatologie, Salle radio' },
  { id: 'eq-018', name: 'Appareil électrothérapie Chattanooga', department: 'Kinésithérapie',                          category: "Équipement biomédical",           serial_number: 'ELT-CHT-2023-001',  status: 'Operational',    manufacturer: 'Chattanooga',             location: 'Kinésithérapie, Salle soins' },
  { id: 'eq-019', name: 'Table de massage électrique',          department: 'Kinésithérapie',                          category: "Équipement biomédical",           serial_number: 'TBL-KIN-2022-001',  status: 'Operational',      manufacturer: 'Medical Supplies Rwanda', location: 'Kinésithérapie, Salle 2' },
  { id: 'eq-020', name: 'Table chauffante néonatale',           department: 'Néonatologie',                            category: "Équipement biomédical",           serial_number: 'TCH-NEO-2023-001',  status: 'Operational',      manufacturer: 'Fisher & Paykel',         location: 'Néonatologie, Unité soins' },
  { id: 'eq-021', name: 'Photothérapie Dräger',                 department: 'Néonatologie',                            category: "Équipement biomédical",           serial_number: 'PHT-DRG-2022-001',  status: 'Operational',    manufacturer: 'Dräger Medical',          location: 'Néonatologie, Chambre 1' },
  { id: 'eq-022', name: 'Moniteur fœtal Philips',               department: 'Maternité',                               category: "Équipement biomédical",           serial_number: 'MON-FOE-2023-001',  status: 'Operational',      manufacturer: 'Philips Healthcare',      location: 'Maternité, Salle accouchement' },
  { id: 'eq-023', name: "Lit d'accouchement hydraulique",       department: 'Maternité',                               category: "Équipement biomédical",           serial_number: 'LIT-MAT-2022-001',  status: 'Operational',      manufacturer: 'Hill-Rom',                location: 'Maternité, Salle 1' },
  { id: 'eq-024', name: 'Scanner IRM Siemens 1.5T',             department: 'Chirurgie',                               category: "Équipement biomédical",           serial_number: 'IRM-SIE-2022-001',  status: 'Operational',      manufacturer: 'Siemens Healthineers',    location: 'Chirurgie, Imagerie' },
  { id: 'eq-025', name: 'Bistouri électrique Valleylab',        department: 'Chirurgie',                               category: "Équipement biomédical",           serial_number: 'BIS-VAL-2023-001',  status: 'Operational',    manufacturer: 'Medtronic',               location: 'Chirurgie, Bloc A' },
  { id: 'eq-026', name: "Table d'opération Maquet",             department: 'Bloc opératoire',                         category: "Équipement biomédical",           serial_number: 'TBL-MAQ-2021-001',  status: 'Operational',      manufacturer: 'Maquet',                  location: 'Bloc opératoire, Salle 1' },
  { id: 'eq-027', name: 'Respirateur anesthésie Dräger Fabius', department: 'Bloc opératoire',                         category: "Équipement biomédical",           serial_number: 'RES-DRG-2022-001',  status: 'Operational',      manufacturer: 'Dräger Medical',          location: 'Bloc opératoire, Salle 1' },
  { id: 'eq-028', name: 'Scialytique LED Trumpf',               department: 'Bloc opératoire',                         category: "Équipement électrique",           serial_number: 'SCI-TRP-2023-001',  status: 'Operational',      manufacturer: 'Trumpf Medical',          location: 'Bloc opératoire, Salle 1' },
  { id: 'eq-029', name: 'Climatisation bloc opératoire',        department: 'Bloc opératoire',                         category: "Équipement électrique",           serial_number: 'CLI-BLO-2021-001',  status: 'Operational',      manufacturer: 'Daikin',                  location: 'Bloc opératoire, Technique' },
  { id: 'eq-030', name: 'Lampe à fente Zeiss SL 800',           department: 'Ophtalmologie',                           category: "Équipement biomédical",           serial_number: 'LAM-ZEI-2023-001',  status: 'Operational',    manufacturer: 'Carl Zeiss',              location: 'Ophtalmologie, Salle examen' },
  { id: 'eq-031', name: 'Tonomètre Applanation',                department: 'Ophtalmologie',                           category: "Équipement biomédical",           serial_number: 'TON-OPH-2022-001',  status: 'Operational',      manufacturer: 'Haag-Streit',             location: 'Ophtalmologie, Consultation' },
  { id: 'eq-032', name: 'Cabine de sécurité biologique classe II', department: 'TB-MR (Tuberculose)',                   category: "Équipement biomédical",           serial_number: 'CSB-TBM-2022-001',  status: 'Operational',      manufacturer: 'Thermo Fisher',           location: 'TB-MR, Laboratoire' },
  { id: 'eq-033', name: "Extracteur d'air HEPA",                department: 'TB-MR (Tuberculose)',                     category: "Équipement électrique",           serial_number: 'EXT-TBM-2023-001',  status: 'Operational',      manufacturer: 'Camfil',                  location: 'TB-MR, Chambre isolement' },
  { id: 'eq-034', name: 'Kit examen médico-légal',              department: 'GBV (Violences basées sur le genre)',     category: "Équipement biomédical",           serial_number: 'KIT-GBV-2023-001',  status: 'Operational',    manufacturer: 'Medical Supplies Rwanda', location: 'GBV, Salle examen' },
  { id: 'eq-035', name: 'Colposcope',                           department: 'GBV (Violences basées sur le genre)',     category: "Équipement biomédical",           serial_number: 'COL-GBV-2022-001',  status: 'Operational',      manufacturer: 'Olympus',                 location: 'GBV, Salle examen' },
  { id: 'eq-036', name: 'Électroencéphalographe Nihon Kohden',  department: 'Santé mentale',                           category: "Équipement biomédical",           serial_number: 'EEG-NKD-2022-001',  status: 'Operational',    manufacturer: 'Nihon Kohden',            location: 'Santé mentale, Salle diagnostic' },
  { id: 'eq-037', name: 'Compteur CD4 BD FACSPresto',           department: 'ARV (Traitement VIH/SIDA)',               category: "Équipement biomédical",           serial_number: 'CD4-BD-2023-001',   status: 'Operational',      manufacturer: 'BD Biosciences',          location: 'ARV, Laboratoire' },
  { id: 'eq-038', name: 'Charge virale Abbott m2000',           department: 'ARV (Traitement VIH/SIDA)',               category: "Équipement biomédical",           serial_number: 'VL-ABT-2022-001',   status: 'Operational',      manufacturer: 'Abbott Molecular',        location: 'ARV, Laboratoire' },
  { id: 'eq-039', name: 'Réfrigérateur vaccins Vestfrost',      department: 'Pharmacie',                               category: 'Pharmacie',                       serial_number: 'REF-VAC-2023-001',  status: 'Operational',      manufacturer: 'Vestfrost',               location: 'Pharmacie, Chambre froide' },
  { id: 'eq-040', name: 'Congélateur -80°C Thermo',             department: 'Pharmacie',                               category: 'Pharmacie',                       serial_number: 'CON-THR-2022-001',  status: 'Operational',      manufacturer: 'Thermo Fisher',           location: 'Pharmacie, Stockage spécialisé' },
  { id: 'eq-041', name: 'Autoclave Steris 400',                 department: 'Bloc opératoire',                         category: 'Stérilisation et buanderie',      serial_number: 'AUT-STR-2022-001',  status: 'Maintenance',manufacturer: 'Steris Corporation',      location: 'Stérilisation, Zone principale' },
  { id: 'eq-042', name: 'Machine à laver industrielle Miele',   department: 'Administration',                          category: 'Stérilisation et buanderie',      serial_number: 'MLI-MIE-2021-001',  status: 'Operational',      manufacturer: 'Miele Professional',      location: 'Buanderie, Zone lavage' },
  { id: 'eq-043', name: 'Séchoir industriel Electrolux',        department: 'Administration',                          category: 'Stérilisation et buanderie',      serial_number: 'SEC-ELX-2021-001',  status: 'Operational',      manufacturer: 'Electrolux Professional', location: 'Buanderie, Zone séchage' },
  { id: 'eq-044', name: 'Distributeur gel hydroalcoolique automatique', department: 'Administration',                  category: "Matériel d'hygiène",              serial_number: 'DIS-HYG-2023-001',  status: 'Operational',    manufacturer: 'Medical Supplies Rwanda', location: 'Administration, Entrée principale' },
  { id: 'eq-045', name: 'Poubelle médicale à pédale 60L',       department: 'Urgences',                                category: "Matériel d'hygiène",              serial_number: 'POU-HYG-2023-001',  status: 'Operational',      manufacturer: 'Medical Supplies Rwanda', location: 'Urgences, Zone triage' },
];

const maintenanceRecords = [
  { equipment_id: 'eq-001', date: '2024-10-20', intervention: 'Mise à jour firmware',       technician: 'IT Admin. Konaté', is_future: 0 },
  { equipment_id: 'eq-005', date: '2024-09-15', intervention: 'Calibration annuelle',       technician: 'Tech. Baldé',      is_future: 0 },
  { equipment_id: 'eq-005', date: '2025-09-15', intervention: 'Calibration annuelle',       technician: 'Tech. Baldé',      is_future: 1 },
  { equipment_id: 'eq-011', date: '2024-12-01', intervention: 'Vidange et filtres',         technician: 'Tech. Touré',      is_future: 0 },
  { equipment_id: 'eq-011', date: '2025-03-01', intervention: 'Vidange et filtres',         technician: 'Tech. Touré',      is_future: 1 },
  { equipment_id: 'eq-024', date: '2024-11-15', intervention: 'Calibration annuelle',       technician: 'Dr. Kamara',       is_future: 0 },
  { equipment_id: 'eq-024', date: '2024-08-22', intervention: 'Remplacement bobine RF',     technician: 'Tech. Diallo',     is_future: 0 },
  { equipment_id: 'eq-024', date: '2025-02-15', intervention: 'Maintenance trimestrielle',  technician: 'Dr. Kamara',       is_future: 1 },
  { equipment_id: 'eq-041', date: '2024-11-28', intervention: 'Réparation pompe à vide',   technician: 'Tech. Cissé',      is_future: 0 },
];

// ──────────────────────────────────────────────
// LOCATIONS
// ──────────────────────────────────────────────
const locations = [
  { id: 'loc-001', name: 'Salle serveur principale',        building: 'Bâtiment A',       department: 'Administration' },
  { id: 'loc-002', name: 'Salle réseau (baie 2)',           building: 'Bâtiment A',       department: 'Administration' },
  { id: 'loc-003', name: 'Couloir bloc opératoire',         building: 'Bâtiment B',       department: 'Bloc opératoire' },
  { id: 'loc-004', name: 'Générateur de secours',           building: 'Annexe technique', department: 'Infrastructure' },
  { id: 'loc-005', name: 'Local électrique RDC',            building: 'Bâtiment C',       department: 'Infrastructure' },
  { id: 'loc-006', name: 'Réseau eau chaude sanitaire',     building: 'Bâtiment B',       department: 'Infrastructure' },
];

// ──────────────────────────────────────────────
// ISSUES
// ──────────────────────────────────────────────
const issues = [
  { id: 'ISS-001', equipment_id: 'eq-027', equipment_name: 'Respirateur anesthésie Dräger Fabius', department: 'Bloc opératoire', type: 'Équipement biomédical',       description: 'Alarme capteur O2 défaillant, affichage erratique',     reporter: 'Dr. Traoré',           created_at: '2024-12-05 08:30', status: 'En cours',  assigned_technician: 'Tech. Baldé',  diagnosis: 'Capteur O2 HS, besoin de remplacement', actions: null, parts_replaced: null },
  { id: 'ISS-002', equipment_id: 'eq-041', equipment_name: 'Autoclave Steris 400',                 department: 'Bloc opératoire', type: 'Stérilisation et buanderie',  description: 'Pompe à vide ne démarre pas, cycles incomplets',        reporter: 'Inf. Keita',           created_at: '2024-11-28 14:15', status: 'En cours',  assigned_technician: 'Tech. Cissé',  diagnosis: null, actions: null, parts_replaced: null },
  { id: 'ISS-003', equipment_id: 'eq-001', equipment_name: 'Serveur Dell PowerEdge R750',          department: 'Administration',  type: 'Équipement ICT',              description: 'Surchauffe détectée, ventilateurs bruyants',            reporter: 'IT Admin. Konaté',     created_at: '2024-12-08 11:00', status: 'Ouvert',    assigned_technician: null,           diagnosis: null, actions: null, parts_replaced: null },
  { id: 'ISS-004', equipment_id: 'eq-024', equipment_name: 'Scanner IRM Siemens 1.5T',            department: 'Chirurgie',       type: 'Équipement biomédical',       description: 'Bruit anormal pendant acquisition',                     reporter: 'Radiologue Camara',    created_at: '2024-11-20 09:45', status: 'Résolu',    assigned_technician: 'Dr. Kamara',   diagnosis: 'Gradient X désaligné', actions: 'Recalibration gradient', parts_replaced: 'Aucune' },
  { id: 'ISS-005', equipment_id: 'eq-012', equipment_name: 'Analyseur hématologie Sysmex XN-1000', department: 'Laboratoire',    type: 'Équipement biomédical',       description: "Erreur de calibration, résultats incohérents",           reporter: 'Lab. Diallo',          created_at: '2024-12-10 09:00', status: 'Ouvert',    assigned_technician: null,           diagnosis: null, actions: null, parts_replaced: null },
  { id: 'ISS-006', equipment_id: 'eq-022', equipment_name: 'Moniteur fœtal Philips',              department: 'Maternité',       type: 'Équipement biomédical',       description: 'Perte de signal fréquente',                             reporter: 'Sage-femme Mukamana', created_at: '2024-12-09 16:30', status: 'Ouvert',    assigned_technician: null,           diagnosis: null, actions: null, parts_replaced: null },
];

// ──────────────────────────────────────────────
// INVENTORY
// ──────────────────────────────────────────────
const inventory = [
  { id: 'inv-001', name: 'Gants stériles (boîte 100)',       category: 'Consommable médical', current_stock: 45, min_stock: 20, unit: 'boîtes',   status: 'Normal',  last_restocked: '2024-12-01' },
  { id: 'inv-002', name: 'Masques chirurgicaux (boîte 50)',  category: 'Consommable médical', current_stock: 12, min_stock: 15, unit: 'boîtes',   status: 'Faible',  last_restocked: '2024-11-20' },
  { id: 'inv-003', name: 'Seringues 10ml',                   category: 'Consommable médical', current_stock: 0,  min_stock: 50, unit: 'unités',   status: 'Rupture', last_restocked: '2024-10-15' },
  { id: 'inv-004', name: 'Solution hydroalcoolique (5L)',    category: 'Hygiène',             current_stock: 8,  min_stock: 5,  unit: 'bidons',   status: 'Normal',  last_restocked: '2024-12-05' },
  { id: 'inv-005', name: 'Désinfectant surface (1L)',        category: 'Hygiène',             current_stock: 3,  min_stock: 10, unit: 'bouteilles',status: 'Faible',  last_restocked: '2024-11-10' },
  { id: 'inv-006', name: 'Cathéters IV (boîte 50)',          category: 'Consommable médical', current_stock: 25, min_stock: 10, unit: 'boîtes',   status: 'Normal',  last_restocked: '2024-12-08' },
  { id: 'inv-007', name: 'Compresses stériles (paquet 100)',  category: 'Consommable médical', current_stock: 60, min_stock: 30, unit: 'paquets',  status: 'Normal',  last_restocked: '2024-12-10' },
];

// ──────────────────────────────────────────────
// SEED
// ──────────────────────────────────────────────
function seed() {
  const db = getDb();

  console.log('Seeding equipment...');
  const insertEq = db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, serial_number, status, manufacturer, location)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);
  for (const e of equipment) {
    insertEq.run(e.id, e.name, e.department, e.category, e.serial_number, e.status, e.manufacturer, e.location);
  }
  console.log(`  ${equipment.length} équipements insérés`);

  console.log('Seeding maintenance records...');
  const insertMaint = db.prepare(`
    INSERT INTO maintenance_records (equipment_id, date, intervention, technician, is_future)
    VALUES (?, ?, ?, ?, ?)
  `);
  // Clear first to avoid duplicates on re-seed
  db.prepare('DELETE FROM maintenance_records').run();
  for (const m of maintenanceRecords) {
    insertMaint.run(m.equipment_id, m.date, m.intervention, m.technician, m.is_future);
  }
  console.log(`  ${maintenanceRecords.length} enregistrements maintenance insérés`);

  console.log('Seeding locations...');
  const insertLoc = db.prepare(`
    INSERT OR IGNORE INTO locations (id, name, building, department)
    VALUES (?, ?, ?, ?)
  `);
  for (const l of locations) {
    insertLoc.run(l.id, l.name, l.building, l.department);
  }
  console.log(`  ${locations.length} lieux insérés`);

  console.log('Seeding issues...');
  const insertIssue = db.prepare(`
    INSERT OR IGNORE INTO issues (id, equipment_id, equipment_name, department, type, description, reporter, created_at, status, assigned_technician, diagnosis, actions, parts_replaced, issue_category, assigned_group)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  for (const i of issues) {
    insertIssue.run(i.id, i.equipment_id, i.equipment_name, i.department, i.type, i.description, i.reporter, i.created_at, i.status, i.assigned_technician, i.diagnosis, i.actions, i.parts_replaced, i.issue_category || 'Biomédical', i.assigned_group || 'Biomédical');
  }
  console.log(`  ${issues.length} incidents insérés`);

  console.log('Seeding inventory...');
  const insertInv = db.prepare(`
    INSERT OR IGNORE INTO inventory (id, name, category, current_stock, min_stock, unit, status, last_restocked)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);
  for (const inv of inventory) {
    insertInv.run(inv.id, inv.name, inv.category, inv.current_stock, inv.min_stock, inv.unit, inv.status, inv.last_restocked);
  }
  console.log(`  ${inventory.length} articles inventaire insérés`);

  closeDb();
  console.log('\nSeed terminé avec succès.');
}

seed();
