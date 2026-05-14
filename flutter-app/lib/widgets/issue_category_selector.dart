import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/issue_form_screen.dart';

/// Ouvre directement [IssueFormScreen] en route plein écran.
/// La sélection de catégorie est désormais intégrée dans le formulaire via les onglets.
void showIssueCategorySelector(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
        body: IssueFormScreen(
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    ),
  );
}
