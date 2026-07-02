import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Badge numérique rouge (pastille de comptage) — réutilisé par la cloche de
/// notifications et les items de navigation (sidebar).
class CountBadge extends StatelessWidget {
  final int count;
  final int maxDisplay;

  const CountBadge({super.key, required this.count, this.maxDisplay = 99});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
      child: Text(
        count > maxDisplay ? '$maxDisplay+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.7),
      ),
    );
  }
}
