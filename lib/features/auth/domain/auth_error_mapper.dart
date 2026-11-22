import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates auth, database, and RPC errors into calm, actionable Indonesian text.
abstract final class AuthErrorMapper {
  static String mapRpcReason(String? reason) {
    switch (reason) {
      case 'invalid_input':
        return 'Nomor registrasi dan PIN aktivasi minimal 4 digit wajib diisi.';
      case 'not_found':
        return 'Nomor registrasi SPPG tidak ditemukan di daftar resmi BGN.';
      case 'already_claimed':
        return 'Nomor registrasi ini sudah diaktifkan sebelumnya. Silakan masuk dengan akun dapur Anda.';
      case 'invalid_pin':
        return 'PIN aktivasi tidak sesuai. Periksa kembali PIN resmi 6 digit Anda.';
      case 'invalid_npsn':
        return 'NPSN wajib berisi tepat 8 digit angka.';
      case 'npsn_exists':
        return 'NPSN ini sudah terdaftar. Gunakan menu Masuk jika sekolah Anda sudah memiliki akun.';
      case 'invalid_invite':
        return 'Kode Mitra SPPG belum diisi.';
      case 'sppg_not_found':
        return 'Kode Mitra SPPG tidak ditemukan. Pastikan penulisan kode sesuai dari dapur mitra Anda.';
      default:
        return 'Validasi data gagal. Periksa kembali isian Anda lalu coba lagi.';
    }
  }

  static String mapException(Object error) {
    if (error is AuthFriendlyException) {
      return error.message;
    }

    if (error is AuthRetryableFetchException) {
      return 'Koneksi ke server akun terganggu sementara. Periksa jaringan Anda lalu coba lagi.';
    }

    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      final code = (error.code ?? '').toLowerCase();
      if (code == 'invalid_credentials' ||
          msg.contains('invalid login credentials')) {
        return 'Email atau kata sandi salah. Periksa kembali penulisan lalu coba lagi.';
      }
      if (code == 'email_not_confirmed' ||
          msg.contains('email not confirmed')) {
        return 'Email akun ini belum dikonfirmasi. Periksa kotak masuk email Anda sebelum masuk.';
      }
      if (code == 'user_already_exists' ||
          code == 'email_exists' ||
          msg.contains('user already registered') ||
          msg.contains('already registered')) {
        return 'Email ini sudah terdaftar. Silakan masuk menggunakan kata sandi Anda.';
      }
      if (code == 'email_address_invalid' ||
          msg.contains('unable to validate email') ||
          (msg.contains('email') && msg.contains('invalid'))) {
        return 'Alamat email ditolak atau tidak dapat menerima verifikasi. Gunakan alamat email aktif yang valid (misalnya Gmail).';
      }
      if (code == 'over_email_send_rate_limit' ||
          code == 'over_request_rate_limit' ||
          msg.contains('rate limit') ||
          msg.contains('too many') ||
          msg.contains('security purposes')) {
        return 'Terlalu banyak percobaan pengiriman email dalam waktu singkat. Tunggu sebentar lalu coba lagi.';
      }
      if (code == 'weak_password' || msg.contains('password')) {
        return 'Kata sandi minimal terdiri dari 8 karakter dengan kombinasi huruf dan angka.';
      }
      if (code == 'signup_disabled' || msg.contains('signups not allowed')) {
        return 'Pendaftaran akun baru sedang dinonaktifkan sementara oleh server.';
      }
      return 'Gagal memproses data akun di server. Periksa kembali isian Anda lalu coba lagi.';
    }

    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('npsn') || error.code == '23505') {
        return 'Data dengan kode atau NPSN tersebut sudah terdaftar di sistem.';
      }
      if (msg.contains('row-level security') || error.code == '42501') {
        return 'Akses ditolak untuk akun ini. Pastikan Anda masuk dengan peran yang sesuai.';
      }
      return 'Gagal menyimpan data ke server. Coba beberapa saat lagi.';
    }

    if (error is SocketException) {
      return 'Tidak ada koneksi internet. Hubungkan HP ke jaringan lalu coba lagi.';
    }

    return 'Terjadi kendala saat memproses permintaan. Periksa jaringan Anda lalu coba lagi.';
  }
}

class AuthFriendlyException implements Exception {
  const AuthFriendlyException(this.message);

  final String message;

  @override
  String toString() => message;
}
