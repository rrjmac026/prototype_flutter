import 'package:flutter/material.dart';

class AuditLog {
  final String id;
  final String plantId;
  final String type;
  final String action;
  final String status;
  final String? details;
  final Map<String, dynamic>? sensorData;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.plantId,
    required this.type,
    required this.action,
    required this.status,
    this.details,
    this.sensorData,
    required this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic value) {
      try {
        if (value is String) {
          return DateTime.parse(value);
        } else if (value is Map && value['\$date'] != null) {
          return DateTime.parse(value['\$date']);
        } else if (value is DateTime) {
          return value;
        }
      } catch (e) {
        debugPrint('Error parsing timestamp: $e');
      }
      return DateTime.now();
    }

    // Handle both 'data' and 'sensorData' fields
    Map<String, dynamic>? sensorData = json['sensorData'];
    if (sensorData == null && json['data'] != null) {
      sensorData = Map<String, dynamic>.from(json['data']);
    }

    return AuditLog(
      id: json['_id'] ?? json['id'] ?? '',
      plantId: json['plantId'] ?? '',
      type: json['type'] ?? '',
      action: json['action'] ?? '',
      status: json['status'] ?? 'success',
      details: json['details'],
      sensorData: sensorData,
      timestamp: parseTimestamp(json['timestamp']),
    );
  }

  String getIcon() {
    switch (type.toLowerCase()) {
      case 'sensor':
        return '📡';
      case 'water':
        return '💧';
      case 'fertilizer':
        return '🌱';
      case 'schedule':
        return '⏰';
      case 'report':
        return '📊';
      case 'system':
        return '⚙️';
      case 'user':
        return '👤';
      case 'maintenance':
        return '🔧';
      case 'notification':
        return '🔔';
      case 'auth':
        return '🔐';
      case 'navigation':
        return '🧭';
      default:
        return '📝';
    }
  }

  String getDisplayTitle() {
    switch (type.toLowerCase()) {
      case 'sensor':
        return 'Sensor Reading';
      case 'water':
        return 'Water System';
      case 'fertilizer':
        return 'Fertilizer';
      case 'schedule':
        return 'Schedule';
      case 'report':
        return 'Report';
      case 'system':
        return 'System';
      case 'user':
        return 'User Activity';
      case 'maintenance':
        return 'Maintenance';
      case 'notification':
        return 'Notification';
      case 'auth':
        return 'Authentication';
      case 'navigation':
        return 'Navigation';
      default:
        return type.toUpperCase();
    }
  }

  Color getColor() {
    switch (status.toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
