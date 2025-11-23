class PlantData {
  final double soilMoisture; // Added this field
  final double temperature;
  final double humidity;
  final String moistureStatus;
  final DateTime timestamp;
  final bool isOnline;

  PlantData({
    required this.soilMoisture, // Changed from moisture to soilMoisture
    required this.temperature,
    required this.humidity,
    required this.moistureStatus,
    required this.timestamp,
    this.isOnline = false, // Add this field
  });

  // Getter for backwards compatibility
  double get moisture => soilMoisture;

  factory PlantData.fromJson(Map<String, dynamic> json) {
    final moisture = json['moisture'];
    final temp = json['temperature'];
    final hum = json['humidity'];
    final timestamp = json['timestamp'] != null
        ? DateTime.parse(json['timestamp'])
        : DateTime.now();

    // Update the valid data check to consider temperature and humidity
    final bool hasValidData = (moisture != null && moisture > 0) ||
        (temp != null && temp > 0) ||
        (hum != null && hum > 0);

    // Also check explicit connection status
    final bool isConnected = json['isConnected'] ?? json['isOnline'] ?? hasValidData;

    return PlantData(
      soilMoisture: _parseDouble(moisture),
      temperature: _parseDouble(temp),
      humidity: _parseDouble(hum),
      moistureStatus: json['moistureStatus'] ?? 'NO_DATA',
      timestamp: timestamp,
      isOnline: isConnected,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'moisture': soilMoisture, // Keep using 'moisture' for API consistency
      'temperature': temperature,
      'humidity': humidity,
      'moistureStatus': moistureStatus,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'moisture': soilMoisture,
      'temperature': temperature,
      'humidity': humidity,
      'moistureStatus': moistureStatus,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

