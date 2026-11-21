import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads runtime environment configuration loaded from `.env`.
abstract final class EnvConfig {
  static String _read(String key) {
    if (!dotenv.isInitialized) {
      return '';
    }
    return dotenv.maybeGet(key)?.trim() ?? '';
  }

  static String get supabaseUrl => _read('SUPABASE_URL');

  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');

  static String get supabasePublishableKey => _read('SUPABASE_PUBLISHABLE_KEY');

  static String get supabaseClientKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : supabaseAnonKey;

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseClientKey.isNotEmpty;
}
