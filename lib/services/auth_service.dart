import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Session? get session => _client.auth.currentSession;
  User? get user => _client.auth.currentUser;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  // username dikirim lewat metadata, trigger SQL di Step 1 yang membuat profilnya
  Future<AuthResponse> signUp(String email, String password, String username) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Kirim email berisi tautan untuk mengatur ulang password.
  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  /// Ganti username (disimpan di metadata akun).
  Future<UserResponse> updateUsername(String username) {
    return _client.auth.updateUser(
      UserAttributes(data: {'username': username}),
    );
  }

  /// Ganti password akun yang sedang login.
  Future<UserResponse> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Ubah pesan error bahasa Inggris dari Supabase jadi bahasa Indonesia.
  static String friendlyError(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Email atau password salah.';
    }
    if (m.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek kotak masuk emailmu.';
    }
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Email ini sudah terdaftar. Coba masuk saja.';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
    }
    if (m.contains('different from the old password') ||
        m.contains('same password')) {
      return 'Password baru tidak boleh sama dengan yang lama.';
    }
    if (m.contains('password should be at least')) {
      return 'Password terlalu pendek.';
    }
    if (m.contains('network') || m.contains('socket')) {
      return 'Tidak ada koneksi internet.';
    }
    return e.message;
  }
}