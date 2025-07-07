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

      // Check if sensors are connected before generating warnings
      final isConnected = freshData['isConnected'] ?? false;
      
      if (!isConnected) {
        // Use a consistent ID for disconnection messages to prevent duplicates
        final disconnectionMessage = Message(
            id: 'sensors_disconnected',  // Fixed ID for disconnection messages
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
    // Generate a more stable ID based on the title to prevent duplicates of the same type
    final stableId = '${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}_${type.toString()}';
    
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
    // Generate a stable ID based on the title and type
    final stableId = '${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}_${type.toString()}';
    
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

  String _getMoistureStatus(num value) {
    if (value >= 1000) return 'SENSOR ERROR';
    if (value > 600) return 'DRY SOIL';
    if (value >= 370) return 'HUMID SOIL';
    return 'IN WATER';
  }

  // This method is kept for backward compatibility but is no longer used for system messages
  void addMessage(Message message) {
    // Check if a message with this ID already exists
    final existingIndex = _messages.indexWhere((m) => m.id == message.id);
    
    if (existingIndex >= 0) {
      // Replace the existing message
      _messages[existingIndex] = message;
    } else {
      // Add as a new message
      _messages.insert(0, message);
    }
    
    _messageController.add(_messages);
    notifyListeners();
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
