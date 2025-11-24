import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  late final GoogleSignIn _googleSignIn;

  AuthService() {
    _googleSignIn = GoogleSignIn(
      serverClientId: '76588160960-iu8sfig920p9gem0ucm4sqc4doj8smrq.apps.googleusercontent.com',
      scopes: ['email', 'profile'],
    );
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToken(data['token']);
        await _saveUserData(data['user']);
        return {'success': true, 'user': data['user']};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'Invalid credentials'};
      } else {
        return {'success': false, 'error': 'Login failed. Please try again.'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error. Please check your internet connection.'
      };
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userData));
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return jsonDecode(userJson);
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<Map<String, dynamic>> googleLogin() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return {'success': false, 'error': 'Google sign-in cancelled'};
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Send token to your backend for verification
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': googleAuth.idToken,
          'accessToken': googleAuth.accessToken,
          'email': googleUser.email,
          'displayName': googleUser.displayName,
          'photoUrl': googleUser.photoUrl,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToken(data['token']);
        await _saveUserData({
          'email': googleUser.email,
          'displayName': googleUser.displayName,
          'photoUrl': googleUser.photoUrl,
          'id': data['user']['id'],
        });
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'error': 'Google authentication failed'};
      }
    } catch (e) {
      debugPrint('Google login error: $e');
      return {
        'success': false,
        'error': 'Google sign-in failed. Please try again.'
      };
    }
  }

  Future<bool> isGoogleSignedIn() async {
    final isSignedIn = await _googleSignIn.isSignedIn();
    return isSignedIn;
  }

  Future<void> googleLogout() async {
    try {
      await _googleSignIn.signOut();
      await logout();
    } catch (e) {
      debugPrint('Google logout error: $e');
    }
  }
}
