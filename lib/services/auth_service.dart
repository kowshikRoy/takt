import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'analytics_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    fb.FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }

  fb.User? get _user => fb.FirebaseAuth.instance.currentUser;

  String? get username => _user?.displayName ?? _user?.email;
  String? get email => _user?.email;
  String? get userId => _user?.uid;

  bool get isAuthenticated => _user != null;

  /// Firebase ID tokens expire hourly, so callers making an authenticated
  /// backend request should fetch a fresh one here rather than caching it.
  Future<String?> getIdToken({bool forceRefresh = false}) {
    return _user?.getIdToken(forceRefresh) ?? Future.value(null);
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      AnalyticsService.logEvent('signup');
      return {'success': true, 'message': 'Registered successfully'};
    } on fb.FirebaseAuthException catch (e) {
      return {'success': false, 'message': _messageFor(e)};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      AnalyticsService.logEvent('login');
      return {'success': true, 'message': 'Logged in successfully'};
    } on fb.FirebaseAuthException catch (e) {
      return {'success': false, 'message': _messageFor(e)};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return {'success': false, 'message': 'Sign-in cancelled'};
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await fb.FirebaseAuth.instance.signInWithCredential(credential);
      AnalyticsService.logEvent('login_google');
      return {'success': true, 'message': 'Logged in successfully'};
    } on fb.FirebaseAuthException catch (e) {
      return {'success': false, 'message': _messageFor(e)};
    } catch (e) {
      return {'success': false, 'message': 'Google sign-in error: $e'};
    }
  }

  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return {'success': true, 'message': 'Password reset email sent'};
    } on fb.FirebaseAuthException catch (e) {
      return {'success': false, 'message': _messageFor(e)};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Best-effort; Firebase sign-out below is what actually matters.
    }
    await fb.FirebaseAuth.instance.signOut();
  }

  String _messageFor(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
}
