import 'package:flutter/foundation.dart';
import '../models/departments.dart';

/// Dynamic department model
class DepartmentItem {
  final String id;
  final String name;
  final String shortName;
  final bool isDefault;

  const DepartmentItem({
    required this.id,
    required this.name,
    required this.shortName,
    this.isDefault = false,
  });

  DepartmentItem copyWith({String? id, String? name, String? shortName, bool? isDefault}) {
    return DepartmentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// Dynamic category model
class CategoryItem {
  final String id;
  final String name;
  final String shortName;
  final bool isDefault;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.shortName,
    this.isDefault = false,
  });

  CategoryItem copyWith({String? id, String? name, String? shortName, bool? isDefault}) {
    return CategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// Configuration service for managing departments and categories
class ConfigService extends ChangeNotifier {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal() {
    _initDefaults();
  }

  final List<DepartmentItem> _departments = [];
  final List<CategoryItem> _categories = [];

  List<DepartmentItem> get departments => List.unmodifiable(_departments);
  List<CategoryItem> get categories => List.unmodifiable(_categories);

  List<String> get departmentNames => _departments.map((d) => d.name).toList();
  List<String> get categoryNames => _categories.map((c) => c.name).toList();

  void _initDefaults() {
    // Initialize departments from enum
    for (final dept in Department.values) {
      _departments.add(DepartmentItem(
        id: 'dept-${dept.name}',
        name: dept.displayName,
        shortName: dept.shortName,
        isDefault: true,
      ));
    }

    // Initialize categories from enum
    for (final cat in EquipmentCategory.values) {
      _categories.add(CategoryItem(
        id: 'cat-${cat.name}',
        name: cat.displayName,
        shortName: cat.shortName,
        isDefault: true,
      ));
    }
  }

  // Department CRUD
  void addDepartment(String name, String shortName) {
    final id = 'dept-${DateTime.now().millisecondsSinceEpoch}';
    _departments.add(DepartmentItem(id: id, name: name, shortName: shortName));
    notifyListeners();
  }

  void updateDepartment(String id, String name, String shortName) {
    final index = _departments.indexWhere((d) => d.id == id);
    if (index != -1) {
      _departments[index] = _departments[index].copyWith(name: name, shortName: shortName);
      notifyListeners();
    }
  }

  void deleteDepartment(String id) {
    _departments.removeWhere((d) => d.id == id && !d.isDefault);
    notifyListeners();
  }

  // Category CRUD
  void addCategory(String name, String shortName) {
    final id = 'cat-${DateTime.now().millisecondsSinceEpoch}';
    _categories.add(CategoryItem(id: id, name: name, shortName: shortName));
    notifyListeners();
  }

  void updateCategory(String id, String name, String shortName) {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index != -1) {
      _categories[index] = _categories[index].copyWith(name: name, shortName: shortName);
      notifyListeners();
    }
  }

  void deleteCategory(String id) {
    _categories.removeWhere((c) => c.id == id && !c.isDefault);
    notifyListeners();
  }
}
