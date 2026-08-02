import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'analytics_service.dart';
import 'app_logger.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    init();
  }

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  String? _token;
  String? _username;
  String? _userId;

  String? get token => _token;
  String? get username => _username;
  String? get userId => _userId;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // One-time migration: earlier versions kept the token in SharedPreferences,
      // which isn't encrypted at rest. Move it into secure storage and drop the
      // plaintext copy so existing sessions survive the upgrade.
      final legacyToken = prefs.getString(_tokenKey);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await _storage.write(key: _tokenKey, value: legacyToken);
        await prefs.remove(_tokenKey);
      }

      _token = await _storage.read(key: _tokenKey);
      _username = prefs.getString('auth_username');
      _userId = prefs.getString('auth_user_id');
      notifyListeners();
    } catch (e) {
      AppLogger.error(
        "Error initializing auth state",
        error: e,
        tag: 'AuthService',
      );
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${Config.backendUrl}/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        _token = data['token'];
        _username = data['user']['username'];
        _userId = data['user']['id'];
        await _saveState();
        notifyListeners();
        AnalyticsService.logEvent('signup');
        return {'success': true, 'message': 'Registered successfully'};
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${Config.backendUrl}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        _token = data['token'];
        _username = data['user']['username'];
        _userId = data['user']['id'];
        await _saveState();
        notifyListeners();
        AnalyticsService.logEvent('login');
        return {'success': true, 'message': 'Logged in successfully'};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<void> logout() async {
    if (_token != null && _token!.isNotEmpty) {
      try {
        await http
            .delete(
              Uri.parse('${Config.backendUrl}/api/auth/logout'),
              headers: {'x-auth-token': _token!},
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Best-effort revoke; local state is cleared regardless.
      }
    }

    _token = null;
    _username = null;
    _userId = null;
    await _storage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_username');
    await prefs.remove('auth_user_id');
    notifyListeners();
  }

  Future<void> _saveState() async {
    if (_token != null) await _storage.write(key: _tokenKey, value: _token!);
    final prefs = await SharedPreferences.getInstance();
    if (_username != null) await prefs.setString('auth_username', _username!);
    if (_userId != null) await prefs.setString('auth_user_id', _userId!);
  }
}
