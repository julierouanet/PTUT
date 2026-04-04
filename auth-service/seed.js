const bcrypt = require('bcrypt');
const { getDb, closeDb } = require('./src/database');
const { BCRYPT_ROUNDS } = require('./src/config');

const users = [
  { id: 'usr-001', name: 'Admin Système', email: 'admin@kabutare.rw', password: 'Admin1234!', role: 'admin', department: 'Administration', phone: '+250 788 123 001' },
  { id: 'usr-002', name: 'Dr. Habimana Jean', email: 'j.habimana@kabutare.rw', password: 'Password1!', role: 'supervisor', department: 'Chirurgie', phone: '+250 788 123 002' },
  { id: 'usr-003', name: 'Mme. Uwimana Claire', email: 'c.uwimana@kabutare.rw', password: 'Password1!', role: 'supervisor', department: 'Maternité', phone: '+250 788 123 003' },
  { id: 'usr-004', name: 'Tech. Baldé Moussa', email: 'm.balde@kabutare.rw', password: 'Password1!', role: 'technician', department: 'Administration', phone: '+250 788 123 004' },
  { id: 'usr-005', name: 'Tech. Cissé Amadou', email: 'a.cisse@kabutare.rw', password: 'Password1!', role: 'technician', department: 'Administration', phone: '+250 788 123 005' },
  { id: 'usr-006', name: 'Dr. Traoré Ibrahim', email: 'i.traore@kabutare.rw', password: 'Password1!', role: 'hospitalStaff', department: 'Bloc opératoire', phone: '+250 788 123 006' },
  { id: 'usr-007', name: 'Inf. Keita Fatou', email: 'f.keita@kabutare.rw', password: 'Password1!', role: 'hospitalStaff', department: 'Urgences', phone: '+250 788 123 007' },
  { id: 'usr-008', name: 'Lab. Diallo Oumar', email: 'o.diallo@kabutare.rw', password: 'Password1!', role: 'hospitalStaff', department: 'Laboratoire', phone: '+250 788 123 008' },
];

async function seed() {
  const db = getDb();

  for (const user of users) {
    const exists = db.prepare('SELECT id FROM users WHERE id = ?').get(user.id);
    if (exists) {
      console.log(`[SKIP] ${user.email} existe déjà`);
      continue;
    }

    const hash = await bcrypt.hash(user.password, BCRYPT_ROUNDS);
    db.prepare(`
      INSERT INTO users (id, name, email, password_hash, role, department, phone, is_active, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, datetime('now'))
    `).run(user.id, user.name, user.email, hash, user.role, user.department, user.phone);

    console.log(`[OK] ${user.email} créé (rôle: ${user.role})`);
  }

  closeDb();
  console.log('\nSeed terminé.');
}

seed().catch(console.error);
