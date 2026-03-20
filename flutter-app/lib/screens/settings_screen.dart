import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/config_service.dart';
import '../services/auth_service.dart';
import '../models/user_role.dart';
import '../providers/locale_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ConfigService _configService = ConfigService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _configService.addListener(_onConfigChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _configService.removeListener(_onConfigChange);
    super.dispose();
  }

  void _onConfigChange() => setState(() {});

  bool get _isAdmin => _authService.hasPermission(Permission.manageDepartments);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ───────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.settings, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text(l10n.settingsSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),

        // ── Section Compte (visible par tous) ────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildAccountSection(l10n),
        ),

        // ── Section Administration (admin seulement) ─────────────────────────
        if (_isAdmin) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(l10n.settingsAdminSection, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ]),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(l10n.settingsAdminSubtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: [
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.business, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.settingsDepartmentsTab(_configService.departments.length)),
                ])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.category, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.settingsCategoriesTab(_configService.categories.length)),
                ])),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildDepartmentsTab(), _buildCategoriesTab()],
            ),
          ),
        ] else
          const SizedBox(height: 24),
      ],
    );
  }

  // ── Section compte ─────────────────────────────────────────────────────────

  Widget _buildAccountSection(AppLocalizations l10n) {
    final localeProvider = LocaleProvider();
    final currentUser = _authService.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.manage_accounts, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(l10n.settingsAccountSection, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 4),
        Text(l10n.settingsAccountSubtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              // Langue
              ListenableBuilder(
                listenable: localeProvider,
                builder: (context, _) => ListTile(
                  leading: const Icon(Icons.language, color: AppColors.primary),
                  title: Text(l10n.settingsLanguage, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(l10n.settingsLanguageSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: DropdownButton<String>(
                    value: localeProvider.locale.languageCode,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(value: 'fr', child: Text(l10n.settingsFrench)),
                      DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                    ],
                    onChanged: (value) {
                      if (value != null) LocaleProvider().setLocale(Locale(value));
                    },
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              // Informations personnelles
              ListTile(
                leading: const Icon(Icons.person_outline, color: AppColors.primary),
                title: Text(l10n.settingsPersonalInfo, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  currentUser?.name ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () => _showPersonalInfoDialog(l10n),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              // Changer mot de passe
              ListTile(
                leading: const Icon(Icons.lock_outline, color: AppColors.primary),
                title: Text(l10n.settingsChangePassword, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(l10n.settingsChangePasswordSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () => _showChangePasswordDialog(l10n),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPersonalInfoDialog(AppLocalizations l10n) {
    final user = _authService.currentUser;
    final nameCtrl  = TextEditingController(text: user?.name ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final deptCtrl  = TextEditingController(text: user?.department ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.settingsPersonalInfo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.settingsFullName,
                  hintText: l10n.settingsFullNameHint,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.commonEmail,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.settingsPhoneLabel,
                  hintText: l10n.settingsPhoneHint,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deptCtrl,
                decoration: InputDecoration(
                  labelText: l10n.commonDepartment,
                  hintText: l10n.settingsDepartmentHint,
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok = await _authService.updateProfile(
                        name:       nameCtrl.text.trim(),
                        email:      emailCtrl.text.trim(),
                        phone:      phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                        department: deptCtrl.text.trim(),
                      );
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? l10n.settingsProfileUpdated : l10n.commonError),
                          backgroundColor: ok ? AppColors.success : AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                    child: Text(l10n.commonSave),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(AppLocalizations l10n) {
    final newPassCtrl   = TextEditingController();
    final confirmCtrl   = TextEditingController();
    bool obscureNew     = true;
    bool obscureConfirm = true;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.settingsChangePassword, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: l10n.settingsNewPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: l10n.settingsConfirmPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final newPass = newPassCtrl.text;
                        final confirm = confirmCtrl.text;
                        if (newPass.length < 6) {
                          setDialogState(() => errorMsg = l10n.settingsPasswordMinLength);
                          return;
                        }
                        if (newPass != confirm) {
                          setDialogState(() => errorMsg = l10n.settingsPasswordMismatch);
                          return;
                        }
                        Navigator.pop(ctx);
                        final ok = await _authService.changePassword(newPass);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ok ? l10n.settingsPasswordChanged : l10n.commonError),
                            backgroundColor: ok ? AppColors.success : AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      child: Text(l10n.commonSave),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Onglets admin ──────────────────────────────────────────────────────────

  Widget _buildDepartmentsTab() {
    final l10n = AppLocalizations.of(context)!;
    final departments = _configService.departments;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showDepartmentDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.settingsNewDepartment),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: departments.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final dept = departments[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                      child: Center(
                        child: Text(
                          dept.shortName.substring(0, dept.shortName.length > 2 ? 2 : dept.shortName.length),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    title: Text(dept.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${l10n.commonAbbreviation}: ${dept.shortName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dept.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                            child: Text(l10n.commonDefault, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          color: AppColors.primary,
                          onPressed: () => _showDepartmentDialog(dept),
                          tooltip: l10n.commonEdit,
                        ),
                        if (!dept.isDefault)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            color: AppColors.error,
                            onPressed: () => _confirmDelete(l10n.settingsDeleteDepartment, dept.name, () {
                              _configService.deleteDepartment(dept.id);
                            }, isFeminine: false),
                            tooltip: l10n.commonDelete,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final l10n = AppLocalizations.of(context)!;
    final categories = _configService.categories;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.settingsNewCategory),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.category, color: AppColors.success, size: 20),
                    ),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${l10n.commonAbbreviation}: ${cat.shortName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                            child: Text(l10n.commonDefault, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          color: AppColors.primary,
                          onPressed: () => _showCategoryDialog(cat),
                          tooltip: l10n.commonEdit,
                        ),
                        if (!cat.isDefault)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            color: AppColors.error,
                            onPressed: () => _confirmDelete(l10n.settingsDeleteCategory, cat.name, () {
                              _configService.deleteCategory(cat.id);
                            }, isFeminine: true),
                            tooltip: l10n.commonDelete,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDepartmentDialog(DepartmentItem? dept) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = dept != null;
    final nameController      = TextEditingController(text: dept?.name ?? '');
    final shortNameController = TextEditingController(text: dept?.shortName ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEdit ? l10n.settingsEditDepartment : l10n.settingsNewDepartment,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.settingsDepartmentName,
                  hintText: l10n.settingsDepartmentNameHint,
                  prefixIcon: const Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: shortNameController,
                decoration: InputDecoration(
                  labelText: l10n.settingsShortName,
                  hintText: l10n.settingsShortNameHint,
                  prefixIcon: const Icon(Icons.short_text),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty || shortNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.commonFillAllFields), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        if (isEdit) {
                          _configService.updateDepartment(dept.id, nameController.text, shortNameController.text);
                        } else {
                          _configService.addDepartment(nameController.text, shortNameController.text);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isEdit ? l10n.settingsDepartmentModified : l10n.settingsDepartmentAdded),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ));
                      },
                      child: Text(isEdit ? l10n.commonSave : l10n.commonAdd),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryDialog(CategoryItem? cat) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = cat != null;
    final nameController      = TextEditingController(text: cat?.name ?? '');
    final shortNameController = TextEditingController(text: cat?.shortName ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEdit ? l10n.settingsEditCategory : l10n.settingsNewCategory,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.settingsCategoryName,
                  hintText: l10n.settingsCategoryNameHint,
                  prefixIcon: const Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: shortNameController,
                decoration: InputDecoration(
                  labelText: l10n.settingsShortName,
                  hintText: l10n.settingsCategoryShortHint,
                  prefixIcon: const Icon(Icons.short_text),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty || shortNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.commonFillAllFields), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        if (isEdit) {
                          _configService.updateCategory(cat.id, nameController.text, shortNameController.text);
                        } else {
                          _configService.addCategory(nameController.text, shortNameController.text);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isEdit ? l10n.settingsCategoryModified : l10n.settingsCategoryAdded),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ));
                      },
                      child: Text(isEdit ? l10n.commonSave : l10n.commonAdd),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String title, String name, VoidCallback onConfirm, {bool isFeminine = false}) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(l10n.settingsDeleteConfirm(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isFeminine ? l10n.settingsDeletedFeminine(title) : l10n.settingsDeleted(title)),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}
