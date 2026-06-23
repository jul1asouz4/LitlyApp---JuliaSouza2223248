import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  static Future<UserCredential?> signInWithGoogle() async {
    // Na web usa-se o popup do Firebase (o pacote google_sign_in não funciona bem na web)
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      return await _auth.signInWithPopup(provider);
    }
    // Mobile (Android/iOS)
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // utilizador cancelou
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  static Future<UserCredential?> signInWithApple() async {
    final provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    if (kIsWeb) {
      return await _auth.signInWithPopup(provider);
    }
    return await _auth.signInWithProvider(provider);
  }

  // ── Login por telemóvel (web) ──────────────────────────────────────────────
  // Envia o SMS e devolve o objeto de confirmação para depois validar o código.
  static Future<ConfirmationResult> sendPhoneCode(String phoneNumber) async {
    return await _auth.signInWithPhoneNumber(phoneNumber);
  }

  static Future<void> signOut() async {
    if (!kIsWeb) {
      try { await _googleSignIn.signOut(); } catch (_) {}
    }
    await _auth.signOut();
  }
}
