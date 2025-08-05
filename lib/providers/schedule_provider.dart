import 'dart:async';
import 'dart:convert';
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final schedules =
          await _scheduleService.getSchedules(plantId, enabled: enabled);
      _schedules = schedules; // Always update with latest data
      _error = null;
      _isLoading = false;
      debugPrint('📅 Fetched ${schedules.length} schedules');
      notifyListeners();
    } catch (e) {
      debugPrint('📅 Error fetching schedules: $e');
      _schedules = []; // Clear schedules on error
      _error = 'Failed to load schedules: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createSchedule(dynamic scheduleInput) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Convert input to proper format based on type
      final Map<String, dynamic> scheduleData;
      if (scheduleInput is Schedule) {
        scheduleData = scheduleInput.toJson();
      } else if (scheduleInput is Map<String, dynamic>) {
        scheduleData = scheduleInput;
      } else {
        throw ArgumentError('Invalid schedule input type');
      }

      // Debug logging
      debugPrint('🔍 Creating schedule with type: ${scheduleData['type']}');
      debugPrint('🔍 Schedule data: ${json.encode(scheduleData)}');

      // Validate and clean schedule data based on type
      if (scheduleData['type'] == 'fertilizing') {
        debugPrint('🔍 Processing fertilizing schedule...');

        // Ensure calendarDays is properly set and days is empty
        if (scheduleData['calendarDays'] == null ||
            (scheduleData['calendarDays'] as List).isEmpty) {
          throw ArgumentError('Fertilizing schedule must have calendar days');
        }

        // Ensure calendarDays are integers
        scheduleData['calendarDays'] =
            (scheduleData['calendarDays'] as List).map((day) {
          if (day is int) return day;
          if (day is String) return int.tryParse(day) ?? 1;
          return 1;
        }).toList();

        scheduleData['days'] = []; // Must be empty for fertilizing

        debugPrint(
            '🔍 Fertilizing calendarDays: ${scheduleData['calendarDays']}');
      } else {
        debugPrint('🔍 Processing watering schedule...');

        // For watering schedules, ensure days is set and calendarDays is empty
        if (scheduleData['days'] == null ||
            (scheduleData['days'] as List).isEmpty) {
          throw ArgumentError('Watering schedule must have days');
        }
        scheduleData['calendarDays'] = []; // Must be empty for watering

        debugPrint('🔍 Watering days: ${scheduleData['days']}');
      }

      debugPrint(
          '🔍 Final schedule data before sending: ${json.encode(scheduleData)}');

      final newSchedule = await _scheduleService
          .createSchedule(Schedule.fromJson(scheduleData))
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
              'Request timed out. Please check your connection and try again.');
        },
      );

      if (newSchedule != null) {
        _schedules.add(newSchedule);
        _isLoading = false;
        notifyListeners();
        debugPrint('✅ Schedule created successfully: ${newSchedule.id}');
        return true;
      } else {
        _error = 'Failed to create schedule: Server returned no data';
        _isLoading = false;
        notifyListeners();
        debugPrint('❌ Schedule creation failed: No data returned');
        return false;
      }
    } on TimeoutException catch (e) {
      _error = e.message ?? 'Request timed out';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Schedule creation timed out: ${e.message}');
      return false;
    } catch (e) {
      _error = 'Failed to create schedule: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Schedule creation error: $e');
      return false;
    }
  }

  Future<bool> updateSchedule(
      String scheduleId, Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate schedule data based on type
      if (data['type'] == 'fertilizing') {
        data['days'] = []; // Clear days array for fertilizing schedules
        if (data['calendarDays'] == null ||
            (data['calendarDays'] as List).isEmpty) {
          throw ArgumentError('Fertilizing schedule must have calendar days');
        }
      } else {
        data['calendarDays'] = []; // Clear calendarDays for watering schedules
        if (data['days'] == null || (data['days'] as List).isEmpty) {
          throw ArgumentError('Watering schedule must have days');
        }
      }

      final success = await _scheduleService.updateSchedule(scheduleId, data);
      if (success) {
        // Update the local schedule
        final index = _schedules.indexWhere((s) => s.id == scheduleId);
        if (index != -1) {
          final updatedSchedule = _schedules[index].copyWith(
            type: data['type'],
            time: data['time'],
            days: data['days'] != null ? List<String>.from(data['days']) : null,
            calendarDays: data['calendarDays'] != null
                ? List<int>.from(data['calendarDays'])
                : null, // FIX: Handle calendarDays
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
    // Find the schedule index
    final index = _schedules.indexWhere((s) => s.id == scheduleId);
    if (index == -1) return false;

    // Store old state in case we need to revert
    final oldSchedule = _schedules[index];

    try {
      // Optimistically update the UI
      _schedules[index] = oldSchedule.copyWith(enabled: enabled);
      notifyListeners();

      // Prepare update data with all necessary fields
      final updateData = {
        'type': oldSchedule.type,
        'time': oldSchedule.time,
        'days': oldSchedule.days,
        'calendarDays': oldSchedule.calendarDays,
        'duration': oldSchedule.duration,
        'enabled': enabled,
        'label': oldSchedule.label,
        'settings': oldSchedule.settings?.toJson(),
      };

      // Make the API call
      final success =
          await _scheduleService.updateSchedule(scheduleId, updateData);

      if (!success) {
        // Revert the change if the API call failed
        _schedules[index] = oldSchedule;
        _error = 'Failed to update schedule';
        notifyListeners();
      }

      return success;
    } catch (e) {
      // Revert the change on error
      _schedules[index] = oldSchedule;
      _error = 'Failed to update schedule: ${e.toString()}';
      notifyListeners();
      return false;
    }
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
