import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_init.dart';
import '../domain/auth_repository.dart';
import 'supabase_auth_repository.dart';
import 'unavailable_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? const UnavailableAuthRepository()
      : SupabaseAuthRepository(client.auth);
});
