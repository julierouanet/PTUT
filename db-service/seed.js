const { getDb, closeDb } = require('./src/database');

// ──────────────────────────────────────────────
// EQUIPMENT
// ──────────────────────────────────────────────
const equipment = [
  { id: 'eq-001', name: 'Dell PowerEdge R750 Server',              department: 'Administration',              category: 'ICT Equipment',            serial_number: 'SRV-DELL-2023-001', status: 'Operational',   manufacturer: 'Dell Technologies',       location: 'Administration, Server Room' },
  { id: 'eq-002', name: 'Cisco Catalyst 9300 Switch',              department: 'Administration',              category: 'ICT Equipment',            serial_number: 'NET-CSC-2023-001',  status: 'Operational',   manufacturer: 'Cisco Systems',           location: 'Administration, Network Room' },
  { id: 'eq-003', name: 'Omron Electronic Blood Pressure Monitor', department: 'OPD (Outpatient Department)', category: 'Biomedical Equipment',     serial_number: 'BP-OMR-2023-001',   status: 'Operational',   manufacturer: 'Omron Healthcare',        location: 'OPD, Consultation Room 1' },
  { id: 'eq-004', name: 'HP ProDesk 400 PC',                       department: 'OPD (Outpatient Department)', category: 'ICT Equipment',            serial_number: 'PC-HP-2023-OPD-001',status: 'Operational',   manufacturer: 'HP Inc.',                 location: 'OPD, Reception' },
  { id: 'eq-005', name: 'Philips 12-Lead ECG',                     department: 'Internal Medicine',           category: 'Biomedical Equipment',     serial_number: 'ECG-PHL-2022-001',  status: 'Operational',   manufacturer: 'Philips Healthcare',      location: 'Internal Medicine, Exam Room' },
  { id: 'eq-006', name: 'Dräger Infinity Patient Monitor',         department: 'Internal Medicine',           category: 'Biomedical Equipment',     serial_number: 'MON-DRG-2023-001',  status: 'Operational',   manufacturer: 'Dräger Medical',          location: 'Internal Medicine, Room 101' },
  { id: 'eq-007', name: 'Atom Neonatal Incubator',                 department: 'Pediatrics',                  category: 'Biomedical Equipment',     serial_number: 'INC-ATM-2022-001',  status: 'Operational',   manufacturer: 'Atom Medical',            location: 'Pediatrics, Neonatal Unit' },
  { id: 'eq-008', name: 'Electronic Baby Scale',                   department: 'Pediatrics',                  category: 'Biomedical Equipment',     serial_number: 'BAL-PED-2023-001',  status: 'Operational',   manufacturer: 'Seca',                    location: 'Pediatrics, Weighing Room' },
  { id: 'eq-009', name: 'Philips HeartStart Defibrillator',        department: 'Emergency',                   category: 'Biomedical Equipment',     serial_number: 'DEF-PHL-2023-001',  status: 'Operational',   manufacturer: 'Philips Healthcare',      location: 'Emergency, Resuscitation Cart' },
  { id: 'eq-010', name: 'Complete Emergency Cart',                 department: 'Emergency',                   category: 'Biomedical Equipment',     serial_number: 'CHR-URG-2022-001',  status: 'Operational',   manufacturer: 'Medical Supplies Rwanda', location: 'Emergency, Triage Area' },
  { id: 'eq-011', name: '250kVA Electric Generator',               department: 'Emergency',                   category: 'Electrical Equipment',     serial_number: 'GEN-CAT-2021-001',  status: 'Operational',   manufacturer: 'Caterpillar',             location: 'Emergency, Technical Area' },
  { id: 'eq-012', name: 'Sysmex XN-1000 Hematology Analyzer',     department: 'Laboratory',                  category: 'Biomedical Equipment',     serial_number: 'HEM-SYS-2023-001',  status: 'Operational',   manufacturer: 'Sysmex Corporation',      location: 'Laboratory, Hematology Room' },
  { id: 'eq-013', name: 'Eppendorf 5430 Centrifuge',               department: 'Laboratory',                  category: 'Biomedical Equipment',     serial_number: 'CEN-EPP-2022-001',  status: 'Operational',   manufacturer: 'Eppendorf',               location: 'Laboratory, Biochemistry Room' },
  { id: 'eq-014', name: 'Olympus CX43 Optical Microscope',         department: 'Laboratory',                  category: 'Biomedical Equipment',     serial_number: 'MIC-OLY-2023-001',  status: 'Operational',   manufacturer: 'Olympus',                 location: 'Laboratory, Parasitology Room' },
  { id: 'eq-015', name: 'Liebherr Reagents Refrigerator',          department: 'Laboratory',                  category: 'Electrical Equipment',     serial_number: 'REF-LIE-2022-001',  status: 'Operational',   manufacturer: 'Liebherr',                location: 'Laboratory, Storage' },
  { id: 'eq-016', name: 'Planmeca Dental Chair',                   department: 'Stomatology',                 category: 'Biomedical Equipment',     serial_number: 'DEN-PLM-2022-001',  status: 'Operational',   manufacturer: 'Planmeca',                location: 'Stomatology, Room 1' },
  { id: 'eq-017', name: 'Panoramic Dental X-Ray',                  department: 'Stomatology',                 category: 'Biomedical Equipment',     serial_number: 'RAD-DEN-2021-001',  status: 'Operational',   manufacturer: 'Carestream Dental',       location: 'Stomatology, X-Ray Room' },
  { id: 'eq-018', name: 'Chattanooga Electrotherapy Device',       department: 'Kinesitherapy',               category: 'Biomedical Equipment',     serial_number: 'ELT-CHT-2023-001',  status: 'Operational',   manufacturer: 'Chattanooga',             location: 'Kinesitherapy, Treatment Room' },
  { id: 'eq-019', name: 'Electric Massage Table',                  department: 'Kinesitherapy',               category: 'Biomedical Equipment',     serial_number: 'TBL-KIN-2022-001',  status: 'Operational',   manufacturer: 'Medical Supplies Rwanda', location: 'Kinesitherapy, Room 2' },
  { id: 'eq-020', name: 'Neonatal Warming Table',                  department: 'Neonatology',                 category: 'Biomedical Equipment',     serial_number: 'TCH-NEO-2023-001',  status: 'Operational',   manufacturer: 'Fisher & Paykel',         location: 'Neonatology, Care Unit' },
  { id: 'eq-021', name: 'Dräger Phototherapy Unit',                department: 'Neonatology',                 category: 'Biomedical Equipment',     serial_number: 'PHT-DRG-2022-001',  status: 'Operational',   manufacturer: 'Dräger Medical',          location: 'Neonatology, Room 1' },
  { id: 'eq-022', name: 'Philips Fetal Monitor',                   department: 'Maternity',                   category: 'Biomedical Equipment',     serial_number: 'MON-FOE-2023-001',  status: 'Operational',   manufacturer: 'Philips Healthcare',      location: 'Maternity, Delivery Room' },
  { id: 'eq-023', name: 'Hydraulic Delivery Bed',                  department: 'Maternity',                   category: 'Biomedical Equipment',     serial_number: 'LIT-MAT-2022-001',  status: 'Operational',   manufacturer: 'Hill-Rom',                location: 'Maternity, Room 1' },
  { id: 'eq-024', name: 'Siemens 1.5T MRI Scanner',               department: 'Surgery',                     category: 'Biomedical Equipment',     serial_number: 'IRM-SIE-2022-001',  status: 'Operational',   manufacturer: 'Siemens Healthineers',    location: 'Surgery, Imaging' },
  { id: 'eq-025', name: 'Valleylab Electrosurgical Unit',          department: 'Surgery',                     category: 'Biomedical Equipment',     serial_number: 'BIS-VAL-2023-001',  status: 'Operational',   manufacturer: 'Medtronic',               location: 'Surgery, Block A' },
  { id: 'eq-026', name: 'Maquet Operating Table',                  department: 'Theater',                     category: 'Biomedical Equipment',     serial_number: 'TBL-MAQ-2021-001',  status: 'Operational',   manufacturer: 'Maquet',                  location: 'Theater, Room 1' },
  { id: 'eq-027', name: 'Dräger Fabius Anesthesia Machine',        department: 'Theater',                     category: 'Biomedical Equipment',     serial_number: 'RES-DRG-2022-001',  status: 'Operational',   manufacturer: 'Dräger Medical',          location: 'Theater, Room 1' },
  { id: 'eq-028', name: 'Trumpf LED Surgical Light',               department: 'Theater',                     category: 'Electrical Equipment',     serial_number: 'SCI-TRP-2023-001',  status: 'Operational',   manufacturer: 'Trumpf Medical',          location: 'Theater, Room 1' },
  { id: 'eq-029', name: 'Operating Theater Air Conditioning',      department: 'Theater',                     category: 'Electrical Equipment',     serial_number: 'CLI-BLO-2021-001',  status: 'Operational',   manufacturer: 'Daikin',                  location: 'Theater, Technical Area' },
  { id: 'eq-030', name: 'Zeiss SL 800 Slit Lamp',                 department: 'Ophthalmology',               category: 'Biomedical Equipment',     serial_number: 'LAM-ZEI-2023-001',  status: 'Operational',   manufacturer: 'Carl Zeiss',              location: 'Ophthalmology, Exam Room' },
  { id: 'eq-031', name: 'Applanation Tonometer',                   department: 'Ophthalmology',               category: 'Biomedical Equipment',     serial_number: 'TON-OPH-2022-001',  status: 'Operational',   manufacturer: 'Haag-Streit',             location: 'Ophthalmology, Consultation' },
  { id: 'eq-032', name: 'Class II Biosafety Cabinet',              department: 'TB-MR',                       category: 'Biomedical Equipment',     serial_number: 'CSB-TBM-2022-001',  status: 'Operational',   manufacturer: 'Thermo Fisher',           location: 'TB-MR, Laboratory' },
  { id: 'eq-033', name: 'HEPA Air Extractor',                      department: 'TB-MR',                       category: 'Electrical Equipment',     serial_number: 'EXT-TBM-2023-001',  status: 'Operational',   manufacturer: 'Camfil',                  location: 'TB-MR, Isolation Room' },
  { id: 'eq-034', name: 'Forensic Examination Kit',                department: 'GBV (Gender-Based Violence Unit)', category: 'Biomedical Equipment', serial_number: 'KIT-GBV-2023-001',  status: 'Operational',   manufacturer: 'Medical Supplies Rwanda', location: 'GBV, Exam Room' },
  { id: 'eq-035', name: 'Colposcope',                              department: 'GBV (Gender-Based Violence Unit)', category: 'Biomedical Equipment', serial_number: 'COL-GBV-2022-001',  status: 'Operational',   manufacturer: 'Olympus',                 location: 'GBV, Exam Room' },
  { id: 'eq-036', name: 'Nihon Kohden Electroencephalograph',      department: 'Mental Health',               category: 'Biomedical Equipment',     serial_number: 'EEG-NKD-2022-001',  status: 'Operational',   manufacturer: 'Nihon Kohden',            location: 'Mental Health, Diagnostic Room' },
  { id: 'eq-037', name: 'BD FACSPresto CD4 Counter',               department: 'ARV (HIV/AIDS Treatment Unit)', category: 'Biomedical Equipment',   serial_number: 'CD4-BD-2023-001',   status: 'Operational',   manufacturer: 'BD Biosciences',          location: 'ARV, Laboratory' },
  { id: 'eq-038', name: 'Abbott m2000 Viral Load Analyzer',        department: 'ARV (HIV/AIDS Treatment Unit)', category: 'Biomedical Equipment',   serial_number: 'VL-ABT-2022-001',   status: 'Operational',   manufacturer: 'Abbott Molecular',        location: 'ARV, Laboratory' },
  { id: 'eq-039', name: 'Vestfrost Vaccine Refrigerator',          department: 'Pharmacy',                    category: 'Pharmacy',                 serial_number: 'REF-VAC-2023-001',  status: 'Operational',   manufacturer: 'Vestfrost',               location: 'Pharmacy, Cold Room' },
  { id: 'eq-040', name: 'Thermo -80°C Freezer',                   department: 'Pharmacy',                    category: 'Pharmacy',                 serial_number: 'CON-THR-2022-001',  status: 'Operational',   manufacturer: 'Thermo Fisher',           location: 'Pharmacy, Specialized Storage' },
  { id: 'eq-041', name: 'Steris 400 Autoclave',                    department: 'Theater',                     category: 'Sterilization and Laundry',serial_number: 'AUT-STR-2022-001',  status: 'Maintenance',   manufacturer: 'Steris Corporation',      location: 'Sterilization, Main Area' },
  { id: 'eq-042', name: 'Miele Industrial Washing Machine',        department: 'Administration',              category: 'Sterilization and Laundry',serial_number: 'MLI-MIE-2021-001',  status: 'Operational',   manufacturer: 'Miele Professional',      location: 'Laundry, Washing Area' },
  { id: 'eq-043', name: 'Electrolux Industrial Dryer',             department: 'Administration',              category: 'Sterilization and Laundry',serial_number: 'SEC-ELX-2021-001',  status: 'Operational',   manufacturer: 'Electrolux Professional', location: 'Laundry, Drying Area' },
  { id: 'eq-044', name: 'Automatic Hand Sanitizer Dispenser',      department: 'Administration',              category: 'Hygiene Materials',        serial_number: 'DIS-HYG-2023-001',  status: 'Operational',   manufacturer: 'Medical Supplies Rwanda', location: 'Administration, Main Entrance' },
  { id: 'eq-045', name: '60L Medical Pedal Bin',                   department: 'Emergency',                   category: 'Hygiene Materials',        serial_number: 'POU-HYG-2023-001',  status: 'Operational',   manufacturer: 'Medical Supplies Rwanda', location: 'Emergency, Triage Area' },
];

const maintenanceRecords = [
  { equipment_id: 'eq-001', date: '2024-10-20', intervention: 'Firmware update',           technician: 'IT Admin. Konaté', is_future: 0 },
  { equipment_id: 'eq-005', date: '2024-09-15', intervention: 'Annual calibration',         technician: 'Tech. Baldé',      is_future: 0 },
  { equipment_id: 'eq-005', date: '2025-09-15', intervention: 'Annual calibration',         technician: 'Tech. Baldé',      is_future: 1 },
  { equipment_id: 'eq-011', date: '2024-12-01', intervention: 'Oil change and filters',     technician: 'Tech. Touré',      is_future: 0 },
  { equipment_id: 'eq-011', date: '2025-03-01', intervention: 'Oil change and filters',     technician: 'Tech. Touré',      is_future: 1 },
  { equipment_id: 'eq-024', date: '2024-11-15', intervention: 'Annual calibration',         technician: 'Dr. Kamara',       is_future: 0 },
  { equipment_id: 'eq-024', date: '2024-08-22', intervention: 'RF coil replacement',        technician: 'Tech. Diallo',     is_future: 0 },
  { equipment_id: 'eq-024', date: '2025-02-15', intervention: 'Quarterly maintenance',      technician: 'Dr. Kamara',       is_future: 1 },
  { equipment_id: 'eq-041', date: '2024-11-28', intervention: 'Vacuum pump repair',         technician: 'Tech. Cissé',      is_future: 0 },
];

// ──────────────────────────────────────────────
// LOCATIONS
// ──────────────────────────────────────────────
const locations = [
  { id: 'loc-001', name: 'Main Server Room',          building: 'Building A',        department: 'Administration' },
  { id: 'loc-002', name: 'Network Room (Bay 2)',       building: 'Building A',        department: 'Administration' },
  { id: 'loc-003', name: 'Theater Corridor',           building: 'Building B',        department: 'Theater' },
  { id: 'loc-004', name: 'Backup Generator',           building: 'Technical Annex',   department: 'Infrastructure' },
  { id: 'loc-005', name: 'Ground Floor Electrical Room', building: 'Building C',      department: 'Infrastructure' },
  { id: 'loc-006', name: 'Hot Water Supply Network',   building: 'Building B',        department: 'Infrastructure' },
];

// ──────────────────────────────────────────────
// ISSUES
// ──────────────────────────────────────────────
const issues = [
  { id: 'ISS-001', equipment_id: 'eq-027', equipment_name: 'Dräger Fabius Anesthesia Machine',    department: 'Theater',       type: 'Biomedical Equipment',     description: 'O2 sensor alarm fault, erratic display',              reporter: 'Dr. Traoré',           created_at: '2024-12-05 08:30', status: 'In Progress', assigned_technician: 'Tech. Baldé',  diagnosis: 'O2 sensor failure, replacement needed', actions: null, parts_replaced: null },
  { id: 'ISS-002', equipment_id: 'eq-041', equipment_name: 'Steris 400 Autoclave',                department: 'Theater',       type: 'Sterilization and Laundry',description: 'Vacuum pump not starting, incomplete cycles',          reporter: 'Inf. Keita',           created_at: '2024-11-28 14:15', status: 'In Progress', assigned_technician: 'Tech. Cissé',  diagnosis: null, actions: null, parts_replaced: null },
  { id: 'ISS-003', equipment_id: 'eq-001', equipment_name: 'Dell PowerEdge R750 Server',          department: 'Administration',type: 'ICT Equipment',            description: 'Overheating detected, noisy fans',                     reporter: 'IT Admin. Konaté',     created_at: '2024-12-08 11:00', status: 'Reported',    assigned_technician: null,           diagnosis: null, actions: null, parts_replaced: null },
  { id: 'ISS-004', equipment_id: 'eq-024', equipment_name: 'Siemens 1.5T MRI Scanner',           department: 'Surgery',       type: 'Biomedical Equipment',     description: 'Abnormal noise during acquisition',                    reporter: 'Radiologist Camara',   created_at: '2024-11-20 09:45', status: 'Completed',   assigned_technician: 'Dr. Kamara',   diagnosis: 'Misaligned X gradient', actions: 'Gradient recalibration', parts_replaced: 'None' },
  { id: 'ISS-005', equipment_id: 'eq-012', equipment_name: 'Sysmex XN-1000 Hematology Analyzer', department: 'Laboratory',    type: 'Biomedical Equipment',     description: 'Calibration error, inconsistent results',              reporter: 'Lab. Diallo',          created_at: '2024-12-10 09:00', status: 'Reported',    assigned_technician: null,           diagnosis: null, actions: null, parts_replaced: null },
  { id: 'ISS-006', equipment_id: 'eq-022', equipment_name: 'Philips Fetal Monitor',               department: 'Maternity',     type: 'Biomedical Equipment',     description: 'Frequent signal loss',                                 reporter: 'Midwife Mukamana',     created_at: '2024-12-09 16:30', status: 'Reported',    assigned_technician: null,           diagnosis: null, actions: null, parts_replaced: null },
];

// ──────────────────────────────────────────────
// INVENTORY
// ──────────────────────────────────────────────
const inventory = [
  { id: 'inv-001', name: 'Sterile Gloves (box of 100)',        category: 'Medical Consumable', current_stock: 45, min_stock: 20, unit: 'boxes',   status: 'Normal', last_restocked: '2024-12-01' },
  { id: 'inv-002', name: 'Surgical Masks (box of 50)',         category: 'Medical Consumable', current_stock: 12, min_stock: 15, unit: 'boxes',   status: 'Low',    last_restocked: '2024-11-20' },
  { id: 'inv-003', name: '10ml Syringes',                      category: 'Medical Consumable', current_stock: 0,  min_stock: 50, unit: 'units',   status: 'Out',    last_restocked: '2024-10-15' },
  { id: 'inv-004', name: 'Hand Sanitizer Solution (5L)',       category: 'Hygiene',            current_stock: 8,  min_stock: 5,  unit: 'cans',    status: 'Normal', last_restocked: '2024-12-05' },
  { id: 'inv-005', name: 'Surface Disinfectant (1L)',          category: 'Hygiene',            current_stock: 3,  min_stock: 10, unit: 'bottles', status: 'Low',    last_restocked: '2024-11-10' },
  { id: 'inv-006', name: 'IV Catheters (box of 50)',           category: 'Medical Consumable', current_stock: 25, min_stock: 10, unit: 'boxes',   status: 'Normal', last_restocked: '2024-12-08' },
  { id: 'inv-007', name: 'Sterile Gauze Pads (pack of 100)',   category: 'Medical Consumable', current_stock: 60, min_stock: 30, unit: 'packs',   status: 'Normal', last_restocked: '2024-12-10' },
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
  console.log(`  ${equipment.length} equipment records inserted`);

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
  console.log(`  ${maintenanceRecords.length} maintenance records inserted`);

  console.log('Seeding locations...');
  const insertLoc = db.prepare(`
    INSERT OR IGNORE INTO locations (id, name, building, department)
    VALUES (?, ?, ?, ?)
  `);
  for (const l of locations) {
    insertLoc.run(l.id, l.name, l.building, l.department);
  }
  console.log(`  ${locations.length} locations inserted`);

  console.log('Seeding issues...');
  const insertIssue = db.prepare(`
    INSERT OR IGNORE INTO issues (id, equipment_id, equipment_name, department, type, description, reporter, created_at, status, assigned_technician, diagnosis, actions, parts_replaced, issue_category, assigned_group)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  for (const i of issues) {
    insertIssue.run(i.id, i.equipment_id, i.equipment_name, i.department, i.type, i.description, i.reporter, i.created_at, i.status, i.assigned_technician, i.diagnosis, i.actions, i.parts_replaced, i.issue_category || 'Biomédical', i.assigned_group || 'Biomédical');
  }
  console.log(`  ${issues.length} issues inserted`);

  console.log('Seeding inventory...');
  const insertInv = db.prepare(`
    INSERT OR IGNORE INTO inventory (id, name, category, current_stock, min_stock, unit, status, last_restocked)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);
  for (const inv of inventory) {
    insertInv.run(inv.id, inv.name, inv.category, inv.current_stock, inv.min_stock, inv.unit, inv.status, inv.last_restocked);
  }
  console.log(`  ${inventory.length} inventory items inserted`);

  closeDb();
  console.log('\nSeed completed successfully.');
}

seed();
