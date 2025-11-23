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
  final Map<String, DateTime> _lastMessageTimestamps =
      {}; // Track last message times

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

      // Check if sensors are connected before generating warnings
      final isConnected = freshData['isConnected'] ?? false;

      if (!isConnected) {
        // Use a consistent ID for disconnection messages to prevent duplicates
        final disconnectionMessage = Message(
            id: 'sensors_disconnected', // Fixed ID for disconnection messages
            title: '📡 Sensors Disconnected',
            content: 'Your plant monitoring sensors appear to be offline.\n\n' +
                'Recommended Actions:\n' +
                '• Check sensor power\n' +
                '• Verify WiFi connection\n' +
                '• Restart the device if needed',
            timestamp: DateTime.now(),
            type: MessageType.info,
            priority: MessagePriority.normal);

        // Remove any existing disconnection messages first
        _messages.removeWhere((m) => m.id == 'sensors_disconnected');

        // Add the new disconnection message
        _messages.insert(0, disconnectionMessage);
        _messageController.add(_messages);
        notifyListeners();
        return;
      }

      // Remove any disconnection messages when sensors are connected
      _messages.removeWhere((m) => m.id == 'sensors_disconnected');

      final moisture = freshData['moisture'] as double;
      final temp = freshData['temperature'] as double;
      final humidity = freshData['humidity'] as double;
      final status =
          _getMoistureStatus(moisture); // Use our corrected status function

      // Fixed Smart Moisture Warnings - corrected logic for percentage-based readings
      if (moisture <= 5) {
        _addWarning(
            '🌵 Critical: Extremely Dry Soil',
            'Current Reading: ${moisture.toStringAsFixed(1)}%\n' +
                'Status: $status\n\n' +
                'Environmental Conditions:\n' +
                '• Temperature: ${temp.toStringAsFixed(1)}°C\n' +
                '• Humidity: ${humidity.toStringAsFixed(1)}%\n\n' +
                'Action Required: Water your plant immediately!',
            MessageType.critical);
      } else if (moisture <= 20) {
        _addWarning(
            '🌿 Warning: Low Moisture',
            'Current Reading: ${moisture.toStringAsFixed(1)}%\n' +
                'Status: $status\n\n' +
                'Environmental Conditions:\n' +
                '• Temperature: ${temp.toStringAsFixed(1)}°C\n' +
                '• Humidity: ${humidity.toStringAsFixed(1)}%\n\n' +
                'Action Required: Consider watering your plant soon',
            MessageType.warning);
      } else if (moisture <= 60) {
        _addWarning(
            '✅ Moisture Level Normal',
            'Current Reading: ${moisture.toStringAsFixed(1)}%\n' +
                'Status: $status\n\n' +
                'Environmental Conditions:\n' +
                '• Temperature: ${temp.toStringAsFixed(1)}°C\n' +
                '• Humidity: ${humidity.toStringAsFixed(1)}%\n\n' +
                'Your plant is in optimal condition',
            MessageType.info);
      } else if (moisture <= 80) {
        _addWarning(
            '💧 High Moisture Level',
            'Current Reading: ${moisture.toStringAsFixed(1)}%\n' +
                'Status: $status\n\n' +
                'Environmental Conditions:\n' +
                '• Temperature: ${temp.toStringAsFixed(1)}°C\n' +
                '• Humidity: ${humidity.toStringAsFixed(1)}%\n\n' +
                'Monitor: Soil moisture is high but acceptable',
            MessageType.info);
      } else {
        _addWarning(
            '🚨 Warning: Oversaturated Soil',
            'Current Reading: ${moisture.toStringAsFixed(1)}%\n' +
                'Status: $status\n\n' +
                'Environmental Conditions:\n' +
                '• Temperature: ${temp.toStringAsFixed(1)}°C\n' +
                '• Humidity: ${humidity.toStringAsFixed(1)}%\n\n' +
                'Warning: Soil may be too wet - check drainage',
            MessageType.warning);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing messages: $e');
    }
  }

  void _addWarning(String title, String content, MessageType type) {
    // Generate a more stable ID based on the title to prevent duplicates of the same type
    final stableId =
        '${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}_${type.toString()}';

    final message = Message(
        id: stableId,
        title: title,
        content: content,
        timestamp: DateTime.now(),
        type: type,
        priority: _getPriorityForMessage(type));

    // Remove any existing message with the same ID before adding the new one
    _messages.removeWhere((m) => m.id == stableId);
    _messages.insert(0, message);
    _messageController.add(_messages);
    notifyListeners();
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
    // Fixed priority logic for percentage-based moisture readings
    if (value <= 5) return MessagePriority.critical; // Extremely dry
    if (value <= 20) return MessagePriority.warning; // Low moisture
    if (value >= 80) return MessagePriority.warning; // Too wet
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
    // Generate a stable ID based on the title and type
    final stableId =
        '${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}_${type.toString()}';

    final message = Message(
      id: stableId,
      title: title,
      content: content,
      timestamp: DateTime.now(),
      type: type,
      priority: priority,
    );

    // Remove any existing message with the same ID before adding the new one
    _messages.removeWhere((m) => m.id == stableId);
    _messages.insert(0, message);
    _messageController.add(_messages);
    notifyListeners();
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

  // Fixed moisture status function for percentage-based readings
  String _getMoistureStatus(num value) {
    if (value <= 5) return 'EXTREMELY DRY';
    if (value <= 20) return 'DRY SOIL';
    if (value <= 40) return 'SLIGHTLY DRY';
    if (value <= 60) return 'OPTIMAL';
    if (value <= 80) return 'MOIST';
    return 'OVERSATURATED';
  }

  void addMessage(Message message) {
    final messageKey = '${message.type}_${message.title}'; // Create unique key
    final now = DateTime.now();

    // Check if similar message exists and if enough time has passed (30 minutes)
    if (_lastMessageTimestamps.containsKey(messageKey)) {
      final lastTime = _lastMessageTimestamps[messageKey]!;
      if (now.difference(lastTime).inMinutes < 30) {
        return; // Skip if similar message was sent less than 30 minutes ago
      }
    }

    // Update timestamp and add message
    _lastMessageTimestamps[messageKey] = now;
    _messages.insert(0, message);

    // Keep only last 50 messages
    if (_messages.length > 50) {
      _messages.removeLast();
    }

    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _lastMessageTimestamps.clear();
    notifyListeners();
  }

  void initializeMessages() {
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
