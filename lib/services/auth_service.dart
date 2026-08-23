import 'package:supabase_flutter/supabase_flutter.dart';

/// Real authentication using Supabase Auth. Handles register, login,
/// logout, and session check.
///
/// ⚠️ Requires your Supabase project URL/key to be set up in main.dart.
/// Until then, calling register()/login() will throw a clear error
/// (caught by the screens) instead of crashing the whole app.
class AuthService {
  /// Lazy access to the Supabase client — only touched when an auth
  /// action is actually attempted, not the moment this class is created.
  SupabaseClient get _client => Supabase.instance.client;

  Future<AuthResponse> register(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> login(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> logout() => _client.auth.signOut();

  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null; // Supabase not configured yet — treat as logged out
    }
  }

  bool get isLoggedIn => currentUser != null;
}
