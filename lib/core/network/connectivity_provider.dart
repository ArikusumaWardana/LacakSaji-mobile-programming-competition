import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams live offline state (`true` when device has no active network transport).
final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  try {
    final initial = await connectivity.checkConnectivity();
    yield _isDisconnected(initial);
    await for (final results in connectivity.onConnectivityChanged) {
      yield _isDisconnected(results);
    }
  } catch (_) {
    // Default to online when connectivity channels are unavailable in unit tests.
    yield false;
  }
});

bool _isDisconnected(List<ConnectivityResult> results) {
  if (results.isEmpty) {
    return true;
  }
  return results.every((r) => r == ConnectivityResult.none);
}
