// Outil d'audit — inspecte les statuts bruts et la liste des tables (lecture seule).
const path = require('path');
const Database = require(path.resolve(__dirname, '..', '..', 'db-service', 'node_modules', 'better-sqlite3'));
const db = new Database(path.resolve(__dirname, '..', '..', 'db-service', 'hospital.db'), { readonly: true });

console.table(db.prepare('SELECT status, COUNT(*) AS n FROM equipment GROUP BY status ORDER BY n DESC').all());
console.log('Tables :', db.prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").all().map(r => r.name).join(', '));
console.log('Issues :', db.prepare('SELECT COUNT(*) AS n FROM issues').get().n);
db.close();
