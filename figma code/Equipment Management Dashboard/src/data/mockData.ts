import { Equipment, Issue } from '../App';

export const mockEquipment: Equipment[] = [
  {
    id: 'eq-001',
    name: 'Scanner IRM Siemens',
    department: 'Radiologie',
    category: 'Biomédical',
    serialNumber: 'SN-2023-MRI-001',
    status: 'En usage',
    supplier: 'Siemens Healthineers',
    location: 'Bâtiment A, Salle 101',
    maintenanceHistory: [
      {
        date: '2024-11-15',
        intervention: 'Calibration annuelle',
        technician: 'Dr. Kamara'
      },
      {
        date: '2024-08-22',
        intervention: 'Remplacement bobine RF',
        technician: 'Tech. Diallo'
      },
      {
        date: '2024-05-10',
        intervention: 'Maintenance préventive',
        technician: 'Dr. Kamara'
      }
    ],
    futureMaintenance: [
      {
        date: '2025-02-15',
        intervention: 'Maintenance trimestrielle',
        technician: 'Dr. Kamara'
      },
      {
        date: '2025-11-15',
        intervention: 'Calibration annuelle',
        technician: 'À assigner'
      }
    ]
  },
  {
    id: 'eq-002',
    name: 'Générateur électrique 500kVA',
    department: 'Infrastructure',
    category: 'Électrique',
    serialNumber: 'GEN-500-2022-045',
    status: 'Disponible',
    supplier: 'Caterpillar',
    location: 'Zone technique extérieure',
    maintenanceHistory: [
      {
        date: '2024-12-01',
        intervention: 'Vidange et filtres',
        technician: 'Tech. Touré'
      },
      {
        date: '2024-09-15',
        intervention: 'Test de charge',
        technician: 'Ing. Sylla'
      }
    ],
    futureMaintenance: [
      {
        date: '2025-03-01',
        intervention: 'Vidange et filtres',
        technician: 'Tech. Touré'
      }
    ]
  },
  {
    id: 'eq-003',
    name: 'Serveur Dell PowerEdge R750',
    department: 'IT',
    category: 'ICT',
    serialNumber: 'SRV-DELL-2023-078',
    status: 'En usage',
    supplier: 'Dell Technologies',
    location: 'Salle serveur principal',
    maintenanceHistory: [
      {
        date: '2024-10-20',
        intervention: 'Mise à jour firmware',
        technician: 'IT Admin. Konaté'
      },
      {
        date: '2024-07-12',
        intervention: 'Extension RAM 128GB',
        technician: 'IT Admin. Konaté'
      }
    ],
    futureMaintenance: [
      {
        date: '2025-01-20',
        intervention: 'Mise à jour trimestrielle',
        technician: 'IT Admin. Konaté'
      }
    ]
  },
  {
    id: 'eq-004',
    name: 'Respirateur Dräger Evita V300',
    department: 'Réanimation',
    category: 'Biomédical',
    serialNumber: 'RESP-DRG-2021-112',
    status: 'En maintenance',
    supplier: 'Dräger Medical',
    location: 'Bâtiment B, Réanimation',
    maintenanceHistory: [
      {
        date: '2024-12-05',
        intervention: 'Réparation capteur O2',
        technician: 'Tech. Baldé'
      },
      {
        date: '2024-06-18',
        intervention: 'Vérification circuits',
        technician: 'Tech. Baldé'
      }
    ],
    futureMaintenance: [
      {
        date: '2025-06-18',
        intervention: 'Vérification annuelle',
        technician: 'Tech. Baldé'
      }
    ]
  },
  {
    id: 'eq-005',
    name: 'Autoclave Steris',
    department: 'Stérilisation',
    category: 'Biomédical',
    serialNumber: 'AUT-STR-2020-023',
    status: 'Hors service',
    supplier: 'Steris Corporation',
    location: 'Bloc de stérilisation',
    maintenanceHistory: [
      {
        date: '2024-11-28',
        intervention: 'Tentative réparation pompe à vide',
        technician: 'Tech. Cissé'
      },
      {
        date: '2024-03-14',
        intervention: 'Remplacement joints',
        technician: 'Tech. Cissé'
      }
    ],
    futureMaintenance: []
  },
  {
    id: 'eq-006',
    name: 'Switch Cisco Catalyst 9300',
    department: 'IT',
    category: 'ICT',
    serialNumber: 'NET-CSC-2023-156',
    status: 'En usage',
    supplier: 'Cisco Systems',
    location: 'Salle réseau principal',
    maintenanceHistory: [
      {
        date: '2024-11-10',
        intervention: 'Configuration VLANs',
        technician: 'IT Admin. Konaté'
      }
    ],
    futureMaintenance: [
      {
        date: '2025-05-10',
        intervention: 'Audit sécurité réseau',
        technician: 'IT Admin. Konaté'
      }
    ]
  },
  {
    id: 'eq-007',
    name: 'Climatiseur industriel 36000 BTU',
    department: 'Infrastructure',
    category: 'Électrique',
    serialNumber: 'AC-IND-2022-089',
    status: 'Disponible',
    supplier: 'Carrier',
    location: 'Salle serveur',
    maintenanceHistory: [
      {
        date: '2024-09-05',
        intervention: 'Nettoyage filtres et condenseur',
        technician: 'Tech. Touré'
      }
    ],
    futureMaintenance: [
      {
        date: '2025-03-05',
        intervention: 'Maintenance saisonnière',
        technician: 'Tech. Touré'
      }
    ]
  },
  {
    id: 'eq-008',
    name: 'Défibrillateur Philips HeartStart',
    department: 'Urgences',
    category: 'Biomédical',
    serialNumber: 'DEF-PHL-2023-034',
    status: 'Disponible',
    supplier: 'Philips Healthcare',
    location: 'Urgences, Chariot 3',
    maintenanceHistory: [
      {
        date: '2024-10-01',
        intervention: 'Test batteries et électrodes',
        technician: 'Tech. Baldé'
      }
    ],
    futureMaintenance: [
      {
        date: '2025-04-01',
        intervention: 'Test semestriel',
        technician: 'Tech. Baldé'
      }
    ]
  }
];

export const mockIssues: Issue[] = [
  {
    id: 'ISS-001',
    equipmentId: 'eq-004',
    equipmentName: 'Respirateur Dräger Evita V300',
    department: 'Réanimation',
    type: 'Biomédical',
    description: 'Alarme capteur O2 défaillant, affichage erratique des valeurs',
    reporter: 'Dr. Traoré',
    createdAt: '2024-12-05 08:30',
    status: 'In Progress',
    assignedTechnician: 'Tech. Baldé',
    diagnosis: 'Capteur O2 HS, besoin de remplacement',
    actions: 'Commande nouvelle sonde O2 ref. 8415900',
    partsReplaced: ''
  },
  {
    id: 'ISS-002',
    equipmentId: 'eq-005',
    equipmentName: 'Autoclave Steris',
    department: 'Stérilisation',
    type: 'Biomédical',
    description: 'Pompe à vide ne démarre pas, cycles incomplets',
    reporter: 'Inf. Keita',
    createdAt: '2024-11-28 14:15',
    status: 'Open',
    assignedTechnician: 'Tech. Cissé',
    diagnosis: 'Moteur pompe grillé, condensateur défectueux',
    actions: '',
    partsReplaced: ''
  },
  {
    id: 'ISS-003',
    equipmentId: 'eq-003',
    equipmentName: 'Serveur Dell PowerEdge R750',
    department: 'IT',
    type: 'ICT',
    description: 'Surchauffe détectée, ventilateurs bruyants',
    reporter: 'IT Admin. Konaté',
    createdAt: '2024-12-08 11:00',
    status: 'Open',
    assignedTechnician: 'IT Admin. Konaté'
  },
  {
    id: 'ISS-004',
    equipmentId: 'eq-001',
    equipmentName: 'Scanner IRM Siemens',
    department: 'Radiologie',
    type: 'Biomédical',
    description: 'Bruit anormal pendant acquisition, images floues',
    reporter: 'Radiologue Camara',
    createdAt: '2024-11-20 09:45',
    status: 'Resolved',
    assignedTechnician: 'Dr. Kamara',
    diagnosis: 'Gradient X désaligné',
    actions: 'Recalibration gradient, test qualité image',
    partsReplaced: 'Aucune'
  },
  {
    id: 'ISS-005',
    equipmentId: 'eq-002',
    equipmentName: 'Générateur électrique 500kVA',
    department: 'Infrastructure',
    type: 'Électrique',
    description: 'Démarrage difficile le matin, fumée légère',
    reporter: 'Ing. Sylla',
    createdAt: '2024-12-10 07:20',
    status: 'In Progress',
    assignedTechnician: 'Tech. Touré',
    diagnosis: 'Bougies de préchauffage usées, filtre air sale',
    actions: 'Remplacement bougies, nettoyage filtre',
    partsReplaced: 'Bougies x6'
  },
  {
    id: 'ISS-006',
    equipmentId: 'eq-008',
    equipmentName: 'Défibrillateur Philips HeartStart',
    department: 'Urgences',
    type: 'Biomédical',
    description: 'Batterie faible, voyant rouge clignotant',
    reporter: 'Inf. Chef Diallo',
    createdAt: '2024-12-09 16:30',
    status: 'Resolved',
    assignedTechnician: 'Tech. Baldé',
    diagnosis: 'Batterie en fin de vie',
    actions: 'Remplacement batterie, test défibrillateur',
    partsReplaced: 'Batterie lithium M5070A'
  }
];

export interface InventoryItem {
  id: string;
  name: string;
  category: 'Consommable médical' | 'Hygiène' | 'Bureautique';
  currentStock: number;
  minStock: number;
  unit: string;
  status: 'Normal' | 'Bas' | 'Rupture';
  lastRestocked: string;
}

export const mockInventory: InventoryItem[] = [
  {
    id: 'inv-001',
    name: 'Gants stériles (boîte 100)',
    category: 'Consommable médical',
    currentStock: 45,
    minStock: 20,
    unit: 'boîtes',
    status: 'Normal',
    lastRestocked: '2024-12-01'
  },
  {
    id: 'inv-002',
    name: 'Masques chirurgicaux (boîte 50)',
    category: 'Consommable médical',
    currentStock: 12,
    minStock: 15,
    unit: 'boîtes',
    status: 'Bas',
    lastRestocked: '2024-11-20'
  },
  {
    id: 'inv-003',
    name: 'Seringues 10ml',
    category: 'Consommable médical',
    currentStock: 0,
    minStock: 50,
    unit: 'unités',
    status: 'Rupture',
    lastRestocked: '2024-10-15'
  },
  {
    id: 'inv-004',
    name: 'Solution hydroalcoolique (5L)',
    category: 'Hygiène',
    currentStock: 8,
    minStock: 5,
    unit: 'bidons',
    status: 'Normal',
    lastRestocked: '2024-12-05'
  },
  {
    id: 'inv-005',
    name: 'Papier toilette industriel',
    category: 'Hygiène',
    currentStock: 120,
    minStock: 50,
    unit: 'rouleaux',
    status: 'Normal',
    lastRestocked: '2024-11-28'
  },
  {
    id: 'inv-006',
    name: 'Désinfectant surface (1L)',
    category: 'Hygiène',
    currentStock: 3,
    minStock: 10,
    unit: 'bouteilles',
    status: 'Bas',
    lastRestocked: '2024-11-10'
  },
  {
    id: 'inv-007',
    name: 'Compresses stériles 10x10',
    category: 'Consommable médical',
    currentStock: 25,
    minStock: 30,
    unit: 'paquets',
    status: 'Bas',
    lastRestocked: '2024-11-25'
  },
  {
    id: 'inv-008',
    name: 'Ramettes papier A4',
    category: 'Bureautique',
    currentStock: 18,
    minStock: 10,
    unit: 'ramettes',
    status: 'Normal',
    lastRestocked: '2024-12-03'
  }
];
