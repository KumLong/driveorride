import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class AuthService {

  SupabaseClient get _client => Supabase.instance.client;

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

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isLoggedIn => currentUser != null;

  Future<void> updateProfile({required String fullName, required String phone}) async {
    final user = currentUser;
    if (user == null) throw Exception('Not logged in');
    await _client.from('profiles').update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', user.id);
  }

  Future<void> deleteProfile() async {
    final user = currentUser;
    if (user == null) throw Exception('Not logged in');
    await _client.from('profiles').update({
      'is_deleted': true,
      'full_name': null,
      'phone': null,
    }).eq('id', user.id);
  }

  Future<bool> checkIfDeletedAndSignOutIfSo() async {
    final user = currentUser;
    if (user == null) return false;
    try {
      final data = await _client.from('profiles').select('is_deleted').eq('id', user.id).maybeSingle();
      final isDeleted = data != null && data['is_deleted'] == true;
      if (isDeleted) {
        await logout();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<ProfileModel?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final data = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }
}