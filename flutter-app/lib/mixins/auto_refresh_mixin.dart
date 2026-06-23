import 'dart:async';
import 'package:flutter/widgets.dart';

/// Rafraîchissement automatique périodique pour un écran avec état.
///
/// Usage : appeler [startAutoRefresh] depuis `initState()`. L'annulation du
/// timer est automatique — le mixin surcharge `dispose()` et appelle
/// `super.dispose()`, donc tout écran qui l'utilise doit simplement garder
/// son propre `dispose()` (s'il en a un) tel quel : la chaîne `super.dispose()`
/// s'occupe du reste, aucun appel manuel supplémentaire n'est nécessaire.
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  Timer? _autoRefreshTimer;

  /// Démarre le rafraîchissement périodique : [onRefresh] est appelé toutes
  /// les [interval], avec une garde `mounted` avant chaque déclenchement.
  void startAutoRefresh(Duration interval, Future<void> Function() onRefresh) {
    _autoRefreshTimer = Timer.periodic(interval, (_) {
      if (mounted) onRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
