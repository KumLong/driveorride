import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

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

  /// Registers a new user with Supabase Auth, then creates the matching
  /// row in the `profiles` table (full_name, email, phone) — matches the
  /// `profiles` schema created in the SQL editor.
  ///
  /// ⚠️ The `profiles` insert only succeeds while the user has an active
  /// session (your RLS policy requires auth.uid() = id). If your Supabase
  /// project has "Confirm email" turned on, signUp() won't return a
  /// session yet, and this insert will fail — the auth account is still
  /// created, but the profile row will not be. In that case, either turn
  /// off "Confirm email" in Supabase (Authentication → Providers → Email)
  /// for this project, or create the profile row after the user's first
  /// successful login instead.
  Future<AuthResponse> register(
      String email,
      String password, {
        required String fullName,
        required String phone,
      }) async {
    final response = await _client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user != null) {
      await _client.from('profiles').insert({
        'id': user.id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
      });
    }
    return response;
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

  /// Updates the logged-in user's `profiles` row (full_name, phone) —
  /// used by the editable Profile screen. Email/id are left untouched.
  Future<void> updateProfile({required String fullName, required String phone}) async {
    final user = currentUser;
    if (user == null) throw Exception('Not logged in');
    await _client.from('profiles').update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', user.id);
  }

  /// Fetches the logged-in user's row from the `profiles` table — this is
  /// what makes the Profile screen show the actual name/phone entered at
  /// registration, instead of hardcoded placeholder text. Returns null if
  /// no one is logged in, or if no profile row exists yet (e.g. this
  /// account registered before the profiles table/insert existed).
  Future<ProfileModel?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final data = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }
}