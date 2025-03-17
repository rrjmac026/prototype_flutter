class PlantData {
  final double soilMoisture; // Added this field
  final double temperature;
  final double humidity;
  final String moistureStatus;
  final DateTime timestamp;

  PlantData({
    required this.soilMoisture, // Changed from moisture to soilMoisture
    required this.temperature,
    required this.humidity,
    required this.moistureStatus,
    required this.timestamp,
  });

  // Getter for backwards compatibility
  double get moisture => soilMoisture;

  factory PlantData.fromJson(Map<String, dynamic> json) {
    final moisture = json['moisture'];
    final temp = json['temperature'];
    final hum = json['humidity'];

    return PlantData(
      soilMoisture: _parseDouble(moisture),
      temperature: _parseDouble(temp),
      humidity: _parseDouble(hum),
      moistureStatus: json['moistureStatus'] ?? 'NO_DATA',
      timestamp: DateTime.now(), // Use current time for simplicity
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
}
