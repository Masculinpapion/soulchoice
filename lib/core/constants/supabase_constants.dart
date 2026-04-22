class SupabaseConstants {
  SupabaseConstants._();

  // Set these in .env or dart-define
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_ANON_KEY',
  );

  // Storage buckets
  static const String profilePhotosBucket = 'profile-photos';
  static const String selfiesBucket = 'selfies';

  // Feature flags table
  static const String featureFlagsTable = 'feature_flags';
}
