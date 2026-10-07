/// ProfessorOS – Auth provider (Riverpod AsyncNotifier).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../core/network/dio_client.dart';

/// Holds the current user data or null if not authenticated.
class AuthNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  late final AuthRepository _repo;

  @override
  Future<Map<String, dynamic>?> build() async {
    _repo = AuthRepository();
    final hasToken = await DioClient.hasToken();
    if (!hasToken) return null;
    try {
      return await _repo.getMe();
    } catch (_) {
      await DioClient.clearTokens();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _repo.login(email, password);
      final user = await _repo.getMe();
      state = AsyncData(user);
    } catch (e, st) {
      await DioClient.clearTokens();
      state = AsyncError(e, st);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  Future<void> refreshUser() async {
    try {
      final user = await _repo.getMe();
      state = AsyncData(user);
    } catch (_) {
      await DioClient.clearTokens();
      state = const AsyncData(null);
    }
  }

  bool get isAuthenticated => state.valueOrNull != null;
  String? get userRole => state.valueOrNull?['role'] as String?;
}

final authProvider = AsyncNotifierProvider<AuthNotifier, Map<String, dynamic>?>(
  () => AuthNotifier(),
);
