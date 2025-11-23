import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:prototype/models/plant_data.dart';
import 'package:prototype/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlantDataProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  PlantData? _latestData;
  List<PlantData> _historicalReadings = [];
  bool _isInitialized = false;
  Timer? _updateTimer;
  final _dataController = StreamController<PlantData?>.broadcast();

  static const String _storageKey = 'historical_readings';

  Stream<PlantData?> get dataStream => _dataController.stream;
  bool get isInitialized => _isInitialized;
  PlantData? get latestData => _latestData;
  List<PlantData> get historicalReadings => _historicalReadings;

  Future<void> _saveReadings() async {
    final prefs = await SharedPreferences.getInstance();
    final readingsJson = _historicalReadings
        .map((reading) => {
              'moisture': reading.soilMoisture,
              'temperature': reading.temperature,
              'humidity': reading.humidity,
              'timestamp': reading.timestamp.toIso8601String(),
              'moistureStatus': reading.moistureStatus,
            })
        .toList();
    await prefs.setString(_storageKey, json.encode(readingsJson));
  }

  Future<void> _loadSavedReadings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_storageKey);
      if (savedData != null) {
        final List<dynamic> readingsJson = json.decode(savedData);
        _historicalReadings = readingsJson
            .map((json) => PlantData(
                  soilMoisture: json['moisture'],
                  temperature: json['temperature'],
                  humidity: json['humidity'],
                  timestamp: DateTime.parse(json['timestamp']),
                  moistureStatus: json['moistureStatus'],
                ))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved readings: $e');
    }
  }

  void init() {
    if (!_isInitialized) {
      _loadSavedReadings(); // Load saved readings first
      refreshData();
      _startRealtimeUpdates();
      _isInitialized = true;
    }
  }

  void _startRealtimeUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshData();
    });
  }

  Future<void> refreshData() async {
    try {
      final data =
          await _apiService.getLatestSensorData(ApiService.defaultPlantId);
      _latestData = PlantData.fromJson(data);
      if (_latestData != null) {
        _historicalReadings.insert(0, _latestData!);
        if (_historicalReadings.length > 10) {
          _historicalReadings.removeLast();
        }
        await _saveReadings(); // Save after updating readings
        _dataController.add(_latestData); // Add to stream controller
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    }
  }

  void updateData(PlantData? newData) {
    if (newData != _latestData) {
      _latestData = newData;
      _dataController.add(newData);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _dataController.close();
    super.dispose();
  }
}
