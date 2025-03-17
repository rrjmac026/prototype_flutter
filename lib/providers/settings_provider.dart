import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TempUnit { celsius, fahrenheit, kelvin }

enum Language { english, filipino }

class SettingsProvider with ChangeNotifier {
  TempUnit _tempUnit = TempUnit.celsius;
  Language _language = Language.english;
  bool _pushEnabled = true;
  bool _messageEnabled = true;

  TempUnit get tempUnit => _tempUnit;
  Language get language => _language;
  bool get pushEnabled => _pushEnabled;
  bool get messageEnabled => _messageEnabled;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _tempUnit = TempUnit.values[prefs.getInt('tempUnit') ?? 0];
    _language = Language.values[prefs.getInt('language') ?? 0];
    _pushEnabled = prefs.getBool('pushNotif') ?? true;
    _messageEnabled = prefs.getBool('messageNotif') ?? true;
    notifyListeners();
  }

  Future<void> setTempUnit(TempUnit unit) async {
    _tempUnit = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tempUnit', unit.index);
    notifyListeners();
  }

  Future<void> setLanguage(Language lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('language', lang.index);
    notifyListeners();
  }

  Future<void> setNotifications(bool push, bool message) async {
    _pushEnabled = push;
    _messageEnabled = message;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushNotif', push);
    await prefs.setBool('messageNotif', message);
    notifyListeners();
  }

  String getLocalizedText(String englishText) {
    if (_language == Language.filipino) {
      return _filipinoTranslations[englishText] ?? englishText;
    }
    return englishText;
  }

  String formatTemperature(double temp) {
    switch (_tempUnit) {
      case TempUnit.fahrenheit:
        return '${(temp * 9 / 5 + 32).toStringAsFixed(1)}°F';
      case TempUnit.kelvin:
        return '${(temp + 273.15).toStringAsFixed(1)}K';
      default:
        return '${temp.toStringAsFixed(1)}°C';
    }
  }
}

const _filipinoTranslations = {
  'Profile': 'Profil',
  'Settings': 'Mga Setting',
  'Language': 'Wika',
  'Temperature Unit': 'Unit ng Temperatura',
  'Notifications': 'Mga Abiso',
  'Push Notifications': 'Push na Abiso',
  'Message Notifications': 'Mensahe na Abiso',
  'Dark Mode': 'Madilim na Mode',
  'Edit Profile': 'I-edit ang Profil',
  // Add more translations as needed
};
