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
      case 'watering':
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
      case 'watering':
        return 'Water System';
      case 'fertilizer':
        return 'Fertilizer System';
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

  String getActionDisplay() {
    final baseAction = action.replaceAll('_', ' ').toUpperCase();

    // Add more context for watering/fertilizer actions
    if (type.toLowerCase() == 'watering') {
      switch (action.toLowerCase()) {
        case 'started':
          return 'PUMP ACTIVATED';
        case 'completed':
          return 'CYCLE COMPLETED';
        case 'stopped':
          return 'PUMP STOPPED';
        default:
          return baseAction;
      }
    }

    if (type.toLowerCase() == 'fertilizer') {
      switch (action.toLowerCase()) {
        case 'started':
          return 'FEEDING STARTED';
        case 'completed':
          return 'FEEDING COMPLETED';
        case 'stopped':
          return 'FEEDING STOPPED';
        default:
          return baseAction;
      }
    }

    return baseAction;
  }

  // Add helper method to get status reason
  String? getStatusReason() {
    if (type.toLowerCase() == 'watering' ||
        type.toLowerCase() == 'fertilizer') {
      if (details != null && details!.contains('Reason:')) {
        return details!.split('Reason:').last.trim();
      }
    }
    return null;
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

  String? getSystemDetails() {
    if (sensorData != null) {
      List<String> details = [];

      // Add water system status
      if (sensorData!.containsKey('waterState')) {
        final isWatering = sensorData!['waterState'];
        details.add('💧 ${isWatering ? 'WATERING' : 'IDLE'}');
      }

      // Add fertilizer system status
      if (sensorData!.containsKey('fertilizerState')) {
        final isFertilizing = sensorData!['fertilizerState'];
        details.add('🌱 ${isFertilizing ? 'FEEDING' : 'IDLE'}');
      }

      // Add moisture info if available
      if (sensorData!['moisture'] != null && sensorData!['moistureStatus'] != null) {
        details.add('Soil: ${sensorData!['moistureStatus']} (${sensorData!['moisture']}%)');
      }

      // Add system health info if available
      if (sensorData!.containsKey('isConnected')) {
        final connectionStatus = sensorData!['isConnected'] ? '📡 ONLINE' : '❌ OFFLINE';
        details.add(connectionStatus);
      }

      if (details.isNotEmpty) {
        return details.join(' • ');
      }
    }
    return null;
  }

  bool get hasSystemActivity {
    return sensorData != null &&
        ((sensorData!['waterState'] == true ||
                sensorData!['fertilizerState'] == true) ||
            (type.toLowerCase() == 'watering' ||
                type.toLowerCase() == 'fertilizer'));
  }

  // Add helper method to get action-specific details
  String? getActionDetails() {
    if (type.toLowerCase() == 'watering') {
      if (sensorData != null && sensorData!['moisture'] != null) {
        return 'Moisture Level: ${sensorData!['moisture']}% • Status: ${sensorData!['moistureStatus'] ?? 'Unknown'}';
      }
    }
    if (type.toLowerCase() == 'fertilizer') {
      if (details != null) {
        return details;
      }
    }
    return null;
  }
}
