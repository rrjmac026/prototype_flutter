import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  String _username = 'User';

  String get username => _username;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username') ?? 'User';
    notifyListeners();
  }

  Future<void> setUsername(String name) async {
    _username = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
    notifyListeners();
  }
}
