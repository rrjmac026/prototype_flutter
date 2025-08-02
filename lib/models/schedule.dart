import 'package:flutter/foundation.dart';

class Schedule {
  final String? id;
  final String plantId;
  final String type;
  final String time;
  final List<String> days;
  final int duration;
  final bool enabled;
  final String? label;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
  });

  Map<String, dynamic> toJson() {
    return {
      'plantId': plantId,
      'type': type,
      'time': time,
      'days': days,
      'duration': duration,
      'enabled': enabled,
      if (label != null) 'label': label,
    };
  }

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] ?? json['_id']?.toString(),
      plantId: json['plantId'],
      type: json['type'],
      time: json['time'],
      days: List<String>.from(json['days']),
      duration: json['duration'],
      enabled: json['enabled'] ?? true,
      label: json['label'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Schedule copyWith({
    String? id,
    String? plantId,
    String? type,
    String? time,
    List<String>? days,
    int? duration,
    bool? enabled,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      type: type ?? this.type,
      time: time ?? this.time,
      days: days ?? this.days,
      duration: duration ?? this.duration,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Schedule{id: $id, type: $type, time: $time, days: $days, duration: $duration, enabled: $enabled}';
  }
}
