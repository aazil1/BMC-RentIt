// Supabase connection settings and initialization.
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://damfkakuqaqybudsdcfo.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRhbWZrYWt1cWFxeWJ1ZHNkY2ZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIzNzk2MDEsImV4cCI6MjEwNzk1NTYwMX0.EjEggLGLlX7xXQL_aBRjos4TMbhUAviDh6Qmg7Io44I',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabaseAnonKey.trim().isNotEmpty &&
      !supabaseAnonKey.contains('*');

  static Future<void>? _initialization;

  static Future<void> initializeSupabase() async {
    if (!isSupabaseConfigured) {
      throw StateError(
        'Supabase is not configured. Set SUPABASE_URL and '
        'SUPABASE_ANON_KEY to your Supabase project URL and anon/public key.',
      );
    }

    _initialization ??= Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey.trim(),
    ).then((_) {});
    await _initialization;
  }
}
