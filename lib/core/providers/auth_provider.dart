import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => event.session?.user);
});

final currentUserIdProvider = Provider<String?>((ref) {
  // Stream'in ilk emit'ini bekleme — Supabase client hâlihazırda mevcut user'ı tutuyor
  final streamUid = ref.watch(authStateProvider).asData?.value?.id;
  return streamUid ?? Supabase.instance.client.auth.currentUser?.id;
});
