import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prototype/models/plant_data.dart';
import 'package:prototype/services/api_service.dart';

class PlantDataProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  PlantData? _latestData;
  List<PlantData> _historicalReadings = [];
  bool _isInitialized = false;
  Timer? _updateTimer;

  bool get isInitialized => _isInitialized;
  PlantData? get latestData => _latestData;
  List<PlantData> get historicalReadings => _historicalReadings;

  void init() {
    if (!_isInitialized) {
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
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}
