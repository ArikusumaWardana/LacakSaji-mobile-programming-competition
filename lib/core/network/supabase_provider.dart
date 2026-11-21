import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Indicates whether Supabase was initialized with valid `.env` credentials.
final isSupabaseReadyProvider = Provider<bool>((ref) => false);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final isReady = ref.watch(isSupabaseReadyProvider);
  if (!isReady) {
    return null;
  }
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});
