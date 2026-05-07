class SupabaseConstants {
  SupabaseConstants._();

  // Set these in .env or dart-define
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://soulchoice.app',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjIwMDAwMDAwMDB9.woTQjnRf8L27C-dM_8_BJbLZ0cxQ9imH5NBMcDnCnHo',
  );

  // Storage buckets
  static const String profilePhotosBucket = 'profile-photos';
  static const String selfiesBucket = 'selfies';

  // Feature flags table
  static const String featureFlagsTable = 'feature_flags';
}
