import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Three senior-friendly text scale levels defined in DESIGN.md Section 3.3.
enum ComfortableTextScale {
  standard('Standar', 1.0),
  large('Besar', 1.15),
  extraLarge('Ekstra Besar', 1.30);

  const ComfortableTextScale(this.label, this.factor);

  final String label;
  final double factor;

  static ComfortableTextScale fromStorage(String? value) {
    for (final item in ComfortableTextScale.values) {
      if (item.name == value) {
        return item;
      }
    }
    return ComfortableTextScale.standard;
  }
}

/// Overridden in `main.dart` with preloaded preferences; stays null safely in isolated tests.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final textScaleProvider =
    NotifierProvider<TextScaleNotifier, ComfortableTextScale>(
      TextScaleNotifier.new,
    );

class TextScaleNotifier extends Notifier<ComfortableTextScale> {
  @override
  ComfortableTextScale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs?.getString(AppConstants.textScalePrefKey);
    return ComfortableTextScale.fromStorage(saved);
  }

  Future<void> setScale(ComfortableTextScale next) async {
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setString(AppConstants.textScalePrefKey, next.name);
  }
}

/// Applies the in-app comfortable text scale directly on top of the device's
/// base accessibility scale (clamped at 1.0x minimum so Standard is 1.0x,
/// Large is 1.15x, and Extra Large is 1.30x, and capped at 1.6x maximum).
TextScaler effectiveTextScaler(
  MediaQueryData mediaQuery,
  ComfortableTextScale scale,
) {
  final rawSystemFactor = mediaQuery.textScaler.scale(16.0) / 16.0;
  final normalizedBase = rawSystemFactor < 1.0 ? 1.0 : rawSystemFactor;
  final combined = (normalizedBase * scale.factor).clamp(1.0, 1.6);
  return TextScaler.linear(combined);
}
