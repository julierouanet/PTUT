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

  /// French display name (legacy / storage key)
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

  /// Localized display name — use this in the UI
  String localizedName(dynamic l10n) {
    switch (this) {
      case Department.administration:
        return l10n.deptAdministration as String;
      case Department.opd:
        return l10n.deptOpd as String;
      case Department.internalMedicine:
        return l10n.deptInternalMedicine as String;
      case Department.pediatrics:
        return l10n.deptPediatrics as String;
      case Department.emergency:
        return l10n.deptEmergency as String;
      case Department.laboratory:
        return l10n.deptLaboratory as String;
      case Department.stomatology:
        return l10n.deptStomatology as String;
      case Department.kinesitherapy:
        return l10n.deptPhysiotherapy as String;
      case Department.neonatology:
        return l10n.deptNeonatology as String;
      case Department.maternity:
        return l10n.deptMaternity as String;
      case Department.surgery:
        return l10n.deptSurgery as String;
      case Department.theater:
        return l10n.deptOperatingTheater as String;
      case Department.ophthalmology:
        return l10n.deptOphthalmology as String;
      case Department.tbMr:
        return l10n.deptTbMr as String;
      case Department.gbv:
        return l10n.deptGbv as String;
      case Department.mentalHealth:
        return l10n.deptMentalHealth as String;
      case Department.arv:
        return l10n.deptArv as String;
      case Department.pharmacy:
        return l10n.deptPharmacy as String;
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

  /// French display name (legacy / storage key)
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

  /// Localized display name — use this in the UI
  String localizedName(dynamic l10n) {
    switch (this) {
      case EquipmentCategory.ict:
        return l10n.catIct as String;
      case EquipmentCategory.hygiene:
        return l10n.catHygiene as String;
      case EquipmentCategory.biomedical:
        return l10n.catBiomedical as String;
      case EquipmentCategory.electrical:
        return l10n.catElectrical as String;
      case EquipmentCategory.sterilization:
        return l10n.catSterilization as String;
      case EquipmentCategory.pharmacy:
        return l10n.catPharmacy as String;
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
