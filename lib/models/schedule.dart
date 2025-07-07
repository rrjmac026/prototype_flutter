class Schedule {
  final String? id;
  final String plantId;
  final String type; // 'watering' or 'fertilizing'
  final String time; // HH:MM format
  final List<String> days; // Days of the week
  final int duration; // Duration in minutes
  final bool enabled;
  final String? label; // Optional label for the schedule (e.g., "Morning", "Evening")
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

  factory Schedule.fromJson(Map<String, dynamic> json) {
    // Handle potential missing or null values with defaults
    return Schedule(
      id: json['id'],
      plantId: json['plantId'] ?? '',
      type: json['type'] ?? 'watering',
      time: json['time'] ?? '12:00',
      days: json['days'] != null ? List<String>.from(json['days']) : ['Monday'],
      duration: json['duration'] ?? 5,
      enabled: json['enabled'] ?? true,
      label: json['label'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String 
              ? DateTime.parse(json['createdAt'])
              : (json['createdAt'] is DateTime 
                  ? json['createdAt'] 
                  : DateTime.now()))
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is String 
              ? DateTime.parse(json['updatedAt'])
              : (json['updatedAt'] is DateTime 
                  ? json['updatedAt'] 
                  : DateTime.now()))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plantId': plantId,
      'type': type,
      'time': time,
      'days': days,
      'duration': duration,
      'enabled': enabled,
      'label': label,
    };
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
}