/// Hospital departments enumeration
enum Department {
  administration,
  opd,
  internalMedicine,
  pediatrics,
  emergency,
  laboratory,
  stomatology,
  kinesitherapy,
  neonatology,
  maternity,
  surgery,
  theater,
  ophthalmology,
  tbMr,
  gbv,
  mentalHealth,
  arv,
  pharmacy;

  String get displayName {
    switch (this) {
      case Department.administration:
        return 'Administration';
      case Department.opd:
        return 'OPD (Consultations externes)';
      case Department.internalMedicine:
        return 'Médecine interne';
      case Department.pediatrics:
        return 'Pédiatrie';
      case Department.emergency:
        return 'Urgences';
      case Department.laboratory:
        return 'Laboratoire';
      case Department.stomatology:
        return 'Stomatologie';
      case Department.kinesitherapy:
        return 'Kinésithérapie';
      case Department.neonatology:
        return 'Néonatologie';
      case Department.maternity:
        return 'Maternité';
      case Department.surgery:
        return 'Chirurgie';
      case Department.theater:
        return 'Bloc opératoire';
      case Department.ophthalmology:
        return 'Ophtalmologie';
      case Department.tbMr:
        return 'TB-MR (Tuberculose)';
      case Department.gbv:
        return 'GBV (Violences basées sur le genre)';
      case Department.mentalHealth:
        return 'Santé mentale';
      case Department.arv:
        return 'ARV (Traitement VIH/SIDA)';
      case Department.pharmacy:
        return 'Pharmacie';
    }
  }

  String get shortName {
    switch (this) {
      case Department.administration:
        return 'Admin';
      case Department.opd:
        return 'OPD';
      case Department.internalMedicine:
        return 'Méd. Int.';
      case Department.pediatrics:
        return 'Pédiatrie';
      case Department.emergency:
        return 'Urgences';
      case Department.laboratory:
        return 'Labo';
      case Department.stomatology:
        return 'Stomato';
      case Department.kinesitherapy:
        return 'Kiné';
      case Department.neonatology:
        return 'Néonat';
      case Department.maternity:
        return 'Maternité';
      case Department.surgery:
        return 'Chirurgie';
      case Department.theater:
        return 'Bloc op.';
      case Department.ophthalmology:
        return 'Ophtalmo';
      case Department.tbMr:
        return 'TB-MR';
      case Department.gbv:
        return 'GBV';
      case Department.mentalHealth:
        return 'Psy';
      case Department.arv:
        return 'ARV';
      case Department.pharmacy:
        return 'Pharmacie';
    }
  }
}

/// Equipment categories enumeration
enum EquipmentCategory {
  ict,
  hygiene,
  biomedical,
  electrical,
  sterilization,
  pharmacy;

  String get displayName {
    switch (this) {
      case EquipmentCategory.ict:
        return 'Équipement ICT';
      case EquipmentCategory.hygiene:
        return 'Matériel d\'hygiène';
      case EquipmentCategory.biomedical:
        return 'Équipement biomédical';
      case EquipmentCategory.electrical:
        return 'Équipement électrique';
      case EquipmentCategory.sterilization:
        return 'Stérilisation et buanderie';
      case EquipmentCategory.pharmacy:
        return 'Pharmacie';
    }
  }

  String get shortName {
    switch (this) {
      case EquipmentCategory.ict:
        return 'ICT';
      case EquipmentCategory.hygiene:
        return 'Hygiène';
      case EquipmentCategory.biomedical:
        return 'Biomédical';
      case EquipmentCategory.electrical:
        return 'Électrique';
      case EquipmentCategory.sterilization:
        return 'Stérilisation';
      case EquipmentCategory.pharmacy:
        return 'Pharmacie';
    }
  }
}

/// Get all department names as strings
List<String> get allDepartmentNames => Department.values.map((d) => d.displayName).toList();

/// Get all category names as strings
List<String> get allCategoryNames => EquipmentCategory.values.map((c) => c.displayName).toList();
