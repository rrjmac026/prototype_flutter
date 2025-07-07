import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:prototype/models/schedule.dart';
import 'package:prototype/services/schedule_service.dart';
import 'package:prototype/services/api_service.dart';

class ScheduleProvider with ChangeNotifier {
  final ScheduleService _scheduleService = ScheduleService();
  List<Schedule> _schedules = [];
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;

  List<Schedule> get schedules => _schedules;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ScheduleProvider() {
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    // Refresh more frequently to prevent schedules from disappearing
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshSchedules();
    });
  }

  Future<void> refreshSchedules({bool? enabled}) async {
    await fetchSchedules(ApiService.defaultPlantId, enabled: enabled);
  }

  Future<void> fetchSchedules(String plantId, {bool? enabled}) async {
    // Only show loading indicator if we don't have any schedules yet
    final bool showLoading = _schedules.isEmpty;
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final schedules = await _scheduleService.getSchedules(plantId, enabled: enabled);
      
      // Only update if we got schedules back or if our current list is empty
      if (schedules.isNotEmpty || _schedules.isEmpty) {
        _schedules = schedules;
        debugPrint('📅 Fetched ${schedules.length} schedules');
      } else {
        debugPrint('📅 Received empty schedules list, keeping existing data');
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('📅 Error fetching schedules: $e');
      // Only set error if we don't have any schedules
      if (_schedules.isEmpty) {
        _error = 'Failed to load schedules: ${e.toString()}';
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createSchedule(Schedule schedule) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newSchedule = await _scheduleService.createSchedule(schedule);
      if (newSchedule != null) {
        _schedules.add(newSchedule);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to create schedule';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to create schedule: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSchedule(String scheduleId, Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _scheduleService.updateSchedule(scheduleId, data);
      if (success) {
        // Update the local schedule
        final index = _schedules.indexWhere((s) => s.id == scheduleId);
        if (index != -1) {
          final updatedSchedule = _schedules[index].copyWith(
            type: data['type'],
            time: data['time'],
            days: data['days'] != null ? List<String>.from(data['days']) : null,
            duration: data['duration'],
            enabled: data['enabled'],
            label: data['label'],
            updatedAt: DateTime.now(),
          );
          _schedules[index] = updatedSchedule;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to update schedule';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to update schedule: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleScheduleEnabled(String scheduleId, bool enabled) async {
    return updateSchedule(scheduleId, {'enabled': enabled});
  }

  Future<bool> deleteSchedule(String scheduleId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _scheduleService.deleteSchedule(scheduleId);
      if (success) {
        _schedules.removeWhere((s) => s.id == scheduleId);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to delete schedule';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to delete schedule: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}