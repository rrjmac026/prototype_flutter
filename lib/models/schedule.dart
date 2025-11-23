import 'package:flutter/foundation.dart';
import 'dart:convert'; // Add this import

class Schedule {
  final String? id;
  final String plantId;
  final String type;
  final String time;
  final List<String> days;
  final List<int>? calendarDays;
  final int duration;
  final bool enabled;
  final String? label;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ScheduleSettings? settings;
  final String status;
  final DateTime? lastExecuted;

  Schedule({
    this.id,
    required this.plantId,
    required this.type,
    required this.time,
    required this.days,
    required this.duration,
    this.enabled = true,
    this.label,
    this.createdAt,
    this.updatedAt,
    this.settings,
    this.status = 'idle',
    this.lastExecuted,
    this.calendarDays,
  });

  // Replace your existing toJson method in the Schedule class:

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'plantId': plantId,
      'type': type,
      'time': time,
      'duration': duration,
      'enabled': enabled,
      'status': status,
    };

    // Handle different schedule types properly
    if (type == 'fertilizing') {
      // For fertilizing schedules, include calendarDays and empty days array
      json['calendarDays'] = calendarDays ?? [];
      json['days'] = []; // Always empty for fertilizing

      debugPrint(
          '🔍 Fertilizing schedule toJson - calendarDays: ${json['calendarDays']}');
    } else {
      // For watering schedules, include days and empty calendarDays
      json['days'] = days;
      json['calendarDays'] = null; // Can be null for watering

      debugPrint('🔍 Watering schedule toJson - days: ${json['days']}');
    }

    // Add optional fields
    if (label != null && label!.isNotEmpty) {
      json['label'] = label;
    }

    if (settings != null) {
      json['settings'] = settings!.toJson();
    }

    if (lastExecuted != null) {
      json['lastExecuted'] = lastExecuted!.toIso8601String();
    }

    debugPrint('🔍 Schedule.toJson() output: ${jsonEncode(json)}');
    return json;
  }

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] ?? json['_id']?.toString(),
      plantId: json['plantId'],
      type: json['type'],
      time: json['time'],
      days: json['days'] != null ? List<String>.from(json['days']) : [],
      calendarDays: json['calendarDays'] != null
          ? List<int>.from(json['calendarDays'].map((d) {
              if (d is int) return d;
              if (d is String) return int.parse(d);
              return 1; // fallback value
            }))
          : null,
      duration: json['duration'],
      enabled: json['enabled'] ?? true,
      label: json['label'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      settings: json['settings'] != null
          ? ScheduleSettings.fromJson(json['settings'])
          : null,
      status: json['status'] ?? 'idle',
      lastExecuted: json['lastExecuted'] != null
          ? DateTime.parse(json['lastExecuted'])
          : null,
    );
  }

  Schedule copyWith({
    String? id,
    String? plantId,
    String? type,
    String? time,
    List<String>? days,
    List<int>? calendarDays,
    int? duration,
    bool? enabled,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
    ScheduleSettings? settings,
    String? status,
    DateTime? lastExecuted,
  }) {
    return Schedule(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      type: type ?? this.type,
      time: time ?? this.time,
      days: days ?? this.days,
      calendarDays: calendarDays ?? this.calendarDays,
      duration: duration ?? this.duration,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
      status: status ?? this.status,
      lastExecuted: lastExecuted ?? this.lastExecuted,
    );
  }

  @override
  String toString() {
    return 'Schedule{id: $id, type: $type, time: $time, days: $days, calendarDays: $calendarDays, duration: $duration, enabled: $enabled}';
  }
}

class ScheduleSettings {
  final double moistureThreshold;
  final double fertilizerAmount;
  final String moistureMode;
  final String fertilizerMode;

  ScheduleSettings({
    this.moistureThreshold = 40.0,
    this.fertilizerAmount = 50.0,
    this.moistureMode = 'auto',
    this.fertilizerMode = 'scheduled',
  });

  Map<String, dynamic> toJson() {
    return {
      'moistureThreshold': moistureThreshold,
      'fertilizerAmount': fertilizerAmount,
      'moistureMode': moistureMode,
      'fertilizerMode': fertilizerMode,
    };
  }

  factory ScheduleSettings.fromJson(Map<String, dynamic> json) {
    return ScheduleSettings(
      moistureThreshold: json['moistureThreshold']?.toDouble() ?? 40.0,
      fertilizerAmount: json['fertilizerAmount']?.toDouble() ?? 50.0,
      moistureMode: json['moistureMode'] ?? 'auto',
      fertilizerMode: json['fertilizerMode'] ?? 'scheduled',
    );
  }

  ScheduleSettings copyWith({
    double? moistureThreshold,
    double? fertilizerAmount,
    String? moistureMode,
    String? fertilizerMode,
  }) {
    return ScheduleSettings(
      moistureThreshold: moistureThreshold ?? this.moistureThreshold,
      fertilizerAmount: fertilizerAmount ?? this.fertilizerAmount,
      moistureMode: moistureMode ?? this.moistureMode,
      fertilizerMode: fertilizerMode ?? this.fertilizerMode,
    );
  }
}
