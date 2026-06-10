// Outil d'audit GMAO — exécute les requêtes KPI de l'annexe A en LECTURE SEULE.
// Usage : node audit/tools/kpi_queries.js (depuis la racine du projet)
// Ouvre hospital.db avec { readonly: true } — aucune écriture possible.

const path = require('path');
const Database = require(path.resolve(__dirname, '..', '..', 'db-service', 'node_modules', 'better-sqlite3'));

const dbPath = path.resolve(__dirname, '..', '..', 'db-service', 'hospital.db');
const db = new Database(dbPath, { readonly: true });

function run(title, sql) {
  console.log(`\n── ${title} ──`);
  try {
    const rows = db.prepare(sql).all();
    console.table(rows);
  } catch (err) {
    console.log(`⚠️ ${err.message}`);
  }
}

run('Disponibilité par département + global', `
  SELECT department,
         ROUND(100.0 * SUM(status = 'Operational') / COUNT(*), 1) AS dispo_pct,
         COUNT(*) AS total
  FROM equipment GROUP BY department
  UNION ALL
  SELECT 'GLOBAL', ROUND(100.0 * SUM(status = 'Operational') / COUNT(*), 1), COUNT(*) FROM equipment
`);

run('Conformité PM (%)', `
  SELECT COUNT(*) AS nb_plans,
         ROUND(100.0 * SUM(
           last_completed_date IS NOT NULL AND
           date(last_completed_date, '+' || frequency_months || ' months') >= date('now')
         ) / COUNT(*), 1) AS conformite_pm_pct
  FROM preventive_maintenance_plans
`);

run('MTTR approché (jours)', `
  SELECT COUNT(*) AS nb_issues_resolues,
         ROUND(AVG(julianday(updated_at) - julianday(created_at)), 1) AS mttr_jours
  FROM issues WHERE status IN ('Completed', 'Verified', 'Closed')
`);

run('MTBF par équipement (≥ 2 incidents)', `
  SELECT equipment_id,
         ROUND((julianday(MAX(created_at)) - julianday(MIN(created_at))) / (COUNT(*) - 1), 1) AS mtbf_jours,
         COUNT(*) AS nb_incidents
  FROM issues WHERE equipment_id IS NOT NULL
  GROUP BY equipment_id HAVING COUNT(*) >= 2 ORDER BY mtbf_jours ASC LIMIT 15
`);

run('Équipements à incidents répétés (≥ 3)', `
  SELECT equipment_id, equipment_name, COUNT(*) AS nb
  FROM issues WHERE equipment_id IS NOT NULL
  GROUP BY equipment_id HAVING nb >= 3 ORDER BY nb DESC LIMIT 15
`);

run('Remplissage colonnes FEAT-044 (maintenance_records)', `
  SELECT COUNT(*) AS total,
         SUM(checklist_snapshot IS NOT NULL) AS avec_checklist,
         SUM(duration_minutes  IS NOT NULL) AS avec_duree,
         SUM(parts_used        IS NOT NULL) AS avec_pieces,
         SUM(maintenance_type = 'preventive') AS preventives
  FROM maintenance_records
`);

run('Stock — répartition statuts inventory', `
  SELECT status, COUNT(*) AS nb FROM inventory GROUP BY status
`);

db.close();
