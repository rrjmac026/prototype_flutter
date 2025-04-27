import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:prototype/models/message.dart';

class ApiService {
  static const String baseUrl = 'https://server-6x62.onrender.com/api';
  static const String defaultPlantId =
      'C8dA5OfZEC1EGAhkdAB4'; // Match ESP32's FIXED_PLANT_ID
  static const String defaultPlantName = 'Default Plant';

  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Server timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status']?.toString().contains('running') ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  // Get latest sensor data
  Future<Map<String, dynamic>> getLatestSensorData(String plantId) async {
    try {
      debugPrint('Fetching sensor data for plant: $plantId');
      final response = await http.get(
        Uri.parse('$baseUrl/plants/$plantId/latest-sensor-data'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Request timed out');
          throw TimeoutException('Request timed out');
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Raw response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Parsed data: $data');

        if (data == null) {
          debugPrint('Received null data from server');
          return _getDefaultData();
        }

        return {
          'moisture': data['moisture'] ?? 0,
          'temperature': data['temperature'] ?? 0,
          'humidity': data['humidity'] ?? 0,
          'moistureStatus': data['moistureStatus'] ?? 'NO_DATA',
          'timestamp': data['timestamp'] != null
              ? data['timestamp'].toString()
              : DateTime.now().toIso8601String(),
        };
      } else {
        debugPrint('Error response: ${response.statusCode} - ${response.body}');
        return _getDefaultData();
      }
    } on TimeoutException catch (e) {
      debugPrint('Timeout error: $e');
      return _getDefaultData();
    } catch (e) {
      debugPrint('Error fetching sensor data: $e');
      return _getDefaultData();
    }
  }

  Map<String, dynamic> _getDefaultData() {
    return {
      'moisture': 0,
      'temperature': 0,
      'humidity': 0,
      'moistureStatus': 'NO_DATA',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Ensure plant exists
  Future<void> ensurePlantExists() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/plants/$defaultPlantId'),
      );

      if (response.statusCode == 404) {
        // Plant doesn't exist, create it
        await http.post(
          Uri.parse('$baseUrl/plants'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'id': defaultPlantId,
            'name': defaultPlantName,
            'type': 'Indoor Plant',
            'description': 'Default monitoring plant'
          }),
        );
      }
    } catch (e) {
      print('Error ensuring plant exists: $e');
    }
  }

  // Generate report
  Future<List<int>> generateReport(
      String plantId, DateTime start, DateTime end) async {
    try {
      // Check server health first
      final isHealthy = await checkServerHealth();
      if (!isHealthy) {
        throw Exception('Server is not available. Please try again later.');
      }

      final queryParams = {
        'plantId': plantId,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'format': 'pdf'
      };

      final uri =
          Uri.parse('$baseUrl/reports').replace(queryParameters: queryParams);
      debugPrint('Requesting report from: $uri');

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/pdf'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timed out'),
      );

      if (response.statusCode == 200) {
        if (response.bodyBytes.isEmpty) {
          throw Exception('Empty PDF received from server');
        }
        return response.bodyBytes;
      }

      // Handle error responses
      String errorMessage;
      try {
        final errorJson = json.decode(response.body);
        errorMessage = errorJson['error'] ?? 'Unknown server error';
      } catch (_) {
        errorMessage = response.body.contains('<!DOCTYPE html>')
            ? 'Server error: Invalid response format'
            : 'Server error: ${response.statusCode}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('Error generating report: $e');
      rethrow;
    }
  }

  // Get all plants
  Future<List<Map<String, dynamic>>> getPlants() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/plants'));

      if (response.statusCode == 200) {
        List<dynamic> plants = json.decode(response.body);
        return plants.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load plants');
      }
    } catch (e) {
      debugPrint('Error fetching plants: $e');
      rethrow;
    }
  }

  // Update plant
  Future<void> updatePlant(String plantId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/plants/$plantId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update plant');
      }
    } catch (e) {
      debugPrint('Error updating plant: $e');
      rethrow;
    }
  }

  Future<List<Message>> getGSMMessages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/messages'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Message.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch messages');
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      rethrow;
    }
  }
}
