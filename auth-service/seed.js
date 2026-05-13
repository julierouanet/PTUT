const bcrypt = require('bcrypt');
const { getDb, closeDb } = require('./src/database');
const { BCRYPT_ROUNDS } = require('./src/config');
const { setUserRoles } = require('./src/utils/userRoles');

// Tableau `roles` (et plus une string `role`) : chaque user peut en cumuler plusieurs.
// Les techniciens Baldé et Cissé reçoivent les 3 spécialisations pour les tests ;
// les ré-attributions fines se font ensuite via l'interface admin.
const users = [
  { id: 'usr-001', name: 'Admin Système',       email: 'admin@kabutare.rw',       password: 'Admin1234!', roles: ['admin'],                                                            department: 'Administration',     phone: '+250 788 123 001' },
  { id: 'usr-002', name: 'Dr. Habimana Jean',   email: 'j.habimana@kabutare.rw',  password: 'Password1!', roles: ['supervisor'],                                                       department: 'Chirurgie',          phone: '+250 788 123 002' },
  { id: 'usr-003', name: 'Mme. Uwimana Claire', email: 'c.uwimana@kabutare.rw',   password: 'Password1!', roles: ['supervisor'],                                                       department: 'Maternité',          phone: '+250 788 123 003' },
  { id: 'usr-004', name: 'Tech. Baldé Moussa',  email: 'm.balde@kabutare.rw',     password: 'Password1!', roles: ['technician_biomedical', 'technician_it', 'technician_infra'],       department: 'Administration',     phone: '+250 788 123 004' },
  { id: 'usr-005', name: 'Tech. Cissé Amadou',  email: 'a.cisse@kabutare.rw',     password: 'Password1!', roles: ['technician_biomedical', 'technician_it', 'technician_infra'],       department: 'Administration',     phone: '+250 788 123 005' },
  { id: 'usr-006', name: 'Dr. Traoré Ibrahim',  email: 'i.traore@kabutare.rw',    password: 'Password1!', roles: ['hospitalStaff'],                                                    department: 'Bloc opératoire',    phone: '+250 788 123 006' },
  { id: 'usr-007', name: 'Inf. Keita Fatou',    email: 'f.keita@kabutare.rw',     password: 'Password1!', roles: ['hospitalStaff'],                                                    department: 'Urgences',           phone: '+250 788 123 007' },
  { id: 'usr-008', name: 'Lab. Diallo Oumar',   email: 'o.diallo@kabutare.rw',    password: 'Password1!', roles: ['hospitalStaff'],                                                    department: 'Laboratoire',        phone: '+250 788 123 008' },
];

async function seed() {
  const db = getDb();

  for (const user of users) {
    const exists = db.prepare('SELECT id FROM users WHERE id = ?').get(user.id);
    if (exists) {
      // Met à jour les rôles même si le user existe déjà (utile après migration).
      setUserRoles(db, user.id, user.roles);
      console.log(`[SYNC] ${user.email} déjà présent — rôles synchronisés (${user.roles.join(', ')})`);
      continue;
    }

    const hash = await bcrypt.hash(user.password, BCRYPT_ROUNDS);
    const parts = (user.name || '').split(' ');
    const firstName = parts[0] || '';
    const lastName = parts.slice(1).join(' ') || '';

    const tx = db.transaction(() => {
      db.prepare(`
        INSERT INTO users (id, name, first_name, last_name, email, password_hash, department, phone, is_active, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, datetime('now'))
      `).run(user.id, user.name, firstName, lastName, user.email, hash, user.department, user.phone);
      setUserRoles(db, user.id, user.roles);
    });
    tx();

    console.log(`[OK] ${user.email} créé (rôles: ${user.roles.join(', ')})`);
  }

  closeDb();
  console.log('\nSeed terminé.');
}

seed().catch(console.error);
