import 'package:flutter/material.dart';
import 'package:prototype/services/auth_service.dart';
import 'package:prototype/utils/audit_logger.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _user;
  bool _isGoogleSignIn = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get user => _user;
  bool get isGoogleSignIn => _isGoogleSignIn;

  Future<void> init() async {
    _isLoggedIn = await _authService.isLoggedIn();
    if (_isLoggedIn) {
      _user = await _authService.getUserData();
      _isGoogleSignIn = await _authService.isGoogleSignedIn();
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    _isGoogleSignIn = false;
    notifyListeners();

    final result = await _authService.login(email, password);
    
    _isLoading = false;
    
    if (result['success'] == true) {
      _isLoggedIn = true;
      _user = result['user'];
      final userRole = _user?['role'] ?? 'user';
      
      // Log successful login
      await AuditLogger.logUserLogin(email, userRole);
      
      notifyListeners();
      return true;
    } else {
      _error = result['error'] ?? 'Login failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> googleLogin() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.googleLogin();
    
    _isLoading = false;
    
    if (result['success'] == true) {
      _isLoggedIn = true;
      _user = result['user'];
      _isGoogleSignIn = true;
      final userRole = _user?['role'] ?? 'user';
      final email = _user?['email'] ?? 'unknown';
      
      // Log successful Google login
      await AuditLogger.logUserLogin(email, userRole);
      
      notifyListeners();
      return true;
    } else {
      _error = result['error'] ?? 'Google login failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String username, {String role = 'user'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.register(email, password, username, role: role);

    _isLoading = false;

    if (result['success'] == true) {
      _isLoggedIn = true;
      _user = result['user'];
      _isGoogleSignIn = false;
      
      // Log successful registration and login
      await AuditLogger.logUserLogin(email, role);
      
      notifyListeners();
      return true;
    } else {
      _error = result['error'] ?? 'Registration failed';
      notifyListeners();
      return false;
    }
  }

  String? getUserRole() {
    return _user?['role'];
  }

  bool isAdmin() {
    return _user?['role'] == 'admin';
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    // Log logout before clearing user data
    final email = _user?['email'] ?? 'unknown';
    await AuditLogger.logUserLogout(email);

    if (_isGoogleSignIn) {
      await _authService.googleLogout();
    } else {
      await _authService.logout();
    }
    
    _isLoggedIn = false;
    _user = null;
    _error = null;
    _isGoogleSignIn = false;
    _isLoading = false;
    
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
