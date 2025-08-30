import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Try to get from build-time variables, otherwise fall back to .env file
  static String get supabaseUrl {
    const fromEnv = String.fromEnvironment('SUPABASE_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  static String get supabaseAnonKey {
    const fromEnv = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }
}