import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:prototype/models/message.dart';
import 'package:prototype/services/api_service.dart';

class MessageProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Message> _messages = [];
  final _messageController = StreamController<List<Message>>.broadcast();
  Timer? _refreshTimer;
  Map<String, dynamic>? _latestSensorData;

  Stream<List<Message>> get messageStream => _messageController.stream;
  List<Message> get messages => List.from(_messages);
  Map<String, dynamic>? get latestSensorData => _latestSensorData;

  MessageProvider() {
    _startRealtimeUpdates();
  }

  void _startRealtimeUpdates() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      syncSystemMessages();
    });
  }

  Future<void> syncSystemMessages() async {
    try {
      // Actively fetch fresh data
      final freshData =
          await _apiService.getLatestSensorData(ApiService.defaultPlantId);
      _latestSensorData = freshData;

      final moisture = freshData['moisture'] as double;
      final temp = freshData['temperature'] as double;
      final humidity = freshData['humidity'] as double;
      final status = freshData['moistureStatus'] as String;

      // Smart Moisture Warnings with actual readings
      if (moisture >= 1000) {
        _addWarning(
            '🚫 Sensor Reading Error',
            'Current Reading: ${moisture.toStringAsFixed(0)}\n' +
                'Status: $status\n\n' +
                'Environmental Conditions:\n' +
                '• Temperature: ${temp.toStringAsFixed(2)}°C\n' +
                '• Humidity: ${humidity.toStringAsFixed(2)}%\n\n' +
                'Recommended Actions:\n' +
                '• Check sensor placement\n' +
                '• Verify connections\n' +
                '• Ensure proper soil contact',
            MessageType.critical);
      } else if (moisture > 600) {
        _addWarning(
            '🌵 Critical: Low Moisture',
            'Current Reading: ${moisture.toStringAsFixed(0)}\n' +
                'Status: $status\n\n' +
                'Environmental Conditions:\n' +
                '• Temperature: ${temp.toStringAsFixed(2)}°C\n' +
                '• Humidity: ${humidity.toStringAsFixed(2)}%\n\n' +
                'Action Required: Water your plant soon',
            MessageType.warning);
      } else if (moisture >= 370) {
        _addWarning(
            '🌿 Moisture Level Normal',
            'Current Reading: ${moisture.toStringAsFixed(0)}\n' +
                'Status: $status\n\n' +
                'Environmental Conditions:\n' +
                '• Temperature: ${temp.toStringAsFixed(2)}°C\n' +
                '• Humidity: ${humidity.toStringAsFixed(2)}%\n\n' +
                'System is monitoring normally',
            MessageType.info);
      } else {
        _addWarning(
            '💧 High Moisture Alert',
            'Current Reading: ${moisture.toStringAsFixed(0)}\n' +
                'Status: $status\n\n' +
                'Environmental Conditions:\n' +
                '• Temperature: ${temp.toStringAsFixed(2)}°C\n' +
                '• Humidity: ${humidity.toStringAsFixed(2)}%\n\n' +
                'Warning: Soil is overly saturated',
            MessageType.warning);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing messages: $e');
    }
  }

  void _addWarning(String title, String content, MessageType type) {
    final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        timestamp: DateTime.now(),
        type: type,
        priority: _getPriorityForMessage(type));
    addMessage(message);
  }

  MessagePriority _getPriorityForMessage(MessageType type) {
    switch (type) {
      case MessageType.critical:
        return MessagePriority.critical;
      case MessageType.warning:
        return MessagePriority.warning;
      case MessageType.info:
        return MessagePriority.normal;
    }
  }

  MessagePriority _getPriorityForMoisture(num value) {
    if (value >= 1000) return MessagePriority.critical;
    if (value > 600) return MessagePriority.warning;
    return MessagePriority.normal;
  }

  MessagePriority _getPriorityForTemperature(num value) {
    if (value > 30) return MessagePriority.warning;
    return MessagePriority.normal;
  }

  MessagePriority _getPriorityForHumidity(num value) {
    if (value < 40) return MessagePriority.warning;
    return MessagePriority.normal;
  }

  void _addSystemAlert(String title, String content, MessageType type,
      MessagePriority priority) {
    final message = Message(
      id: '${DateTime.now().millisecondsSinceEpoch}_${type.toString()}',
      title: title,
      content: content,
      timestamp: DateTime.now(),
      type: type,
      priority: priority,
    );
    addMessage(message);
  }

  bool _shouldAddStatusUpdate() {
    final lastStatus = _messages.firstWhere(
      (m) => m.type == MessageType.info,
      orElse: () => Message(
        id: '0',
        title: '',
        content: '',
        timestamp: DateTime.now().subtract(const Duration(hours: 7)),
        type: MessageType.info,
      ),
    );
    return DateTime.now().difference(lastStatus.timestamp) >
        const Duration(hours: 6);
  }

  String _getMoistureStatus(num value) {
    if (value >= 1000) return 'SENSOR ERROR';
    if (value > 600) return 'DRY SOIL';
    if (value >= 370) return 'HUMID SOIL';
    return 'IN WATER';
  }

  void addMessage(Message message) {
    // Only add if message doesn't exist
    if (!_messages.any((m) => m.id == message.id)) {
      _messages.insert(0, message);
      _messageController.add(_messages);
      notifyListeners();
    }
  }

  Future<void> initializeMessages() async {
    _addSystemAlert(
        'System Started',
        'Plant monitoring system is active and collecting data.',
        MessageType.info,
        MessagePriority.normal);
  }

  void updateSensorData(Map<String, dynamic> data) {
    _latestSensorData = data;
    syncSystemMessages(); // Trigger sync when new data arrives
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.close();
    super.dispose();
  }
}
