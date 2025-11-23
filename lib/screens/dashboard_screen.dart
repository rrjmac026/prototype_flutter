import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype/providers/plant_data_provider.dart';
import 'package:prototype/providers/settings_provider.dart'; // Add this import
import 'package:prototype/models/plant_data.dart';
import 'package:prototype/providers/user_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:prototype/providers/schedule_provider.dart'; // Add this import
import 'package:prototype/widgets/animated_sensor_card.dart'; // Import the new AnimatedSensorCard widget

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _refreshTimer;
  late StreamSubscription<PlantData?> _dataSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PlantDataProvider>();
      provider.init();

      // Set up real-time data subscription
      _dataSubscription = provider.dataStream.listen((data) {
        if (mounted) {
          provider.updateData(data);
        }
      });

      // Shorter refresh interval for more responsive updates
      _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          provider.refreshData();
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _dataSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(settings.getLocalizedText('Dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<PlantDataProvider>().refreshData(),
          ),
        ],
      ),
      body: Consumer<PlantDataProvider>(
        builder: (context, provider, child) {
          if (!provider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = provider.latestData;
          if (data == null) {
            return Center(
              child: Text(settings.getLocalizedText('No data available')),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingCard(),
                const SizedBox(height: 16),
                _buildMonitoringGrid(provider.latestData),
                const SizedBox(height: 16),
                _buildSensorChart(provider.latestData!),
                const SizedBox(height: 16),
                _buildWateringSchedule(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGreetingCard() {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.teal.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.wb_sunny, color: Colors.yellow.shade300, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      final username = userProvider.username ?? 'User';
                      return Text(
                        'Good Morning, $username!',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        softWrap: true,
                      );
                    },
                  ),
                  const Text(
                    'Your garden is doing well today.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringGrid(PlantData? data) {
  final bool isOnline = data?.isOnline ?? false;
  return Consumer<SettingsProvider>(
    builder: (context, settings, child) {
      return Column(
        children: [
          if (!isOnline)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sensors Offline',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Check sensor connections',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Improved GridView with better constraints
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final cardWidth = (screenWidth - 32 - 12) / 2; // Account for padding and spacing
              final cardHeight = cardWidth * 0.95; // Better aspect ratio - closer to square
              
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12, // Increased spacing
                crossAxisSpacing: 12, // Increased spacing
                childAspectRatio: cardWidth / cardHeight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  AnimatedSensorCard(
                    icon: Icons.water_drop,
                    title: 'Soil Moisture',
                    value: isOnline ? '${data?.soilMoisture.toStringAsFixed(1)}%' : 'N/A',
                    color: isOnline ? _getMoistureColor(data?.soilMoisture ?? 0) : Colors.grey,
                    isOnline: isOnline,
                    type: 'moisture',
                    percentage: data?.soilMoisture ?? 0,
                  ),
                  AnimatedSensorCard(
                    icon: Icons.thermostat,
                    title: settings.getLocalizedText('Temperature'),
                    value: data != null ? settings.formatTemperature(data.temperature) : 'N/A',
                    color: isOnline ? Colors.orange.shade600 : Colors.grey,
                    isOnline: isOnline,
                    type: 'temperature',
                    percentage: data?.temperature ?? 0,
                  ),
                  AnimatedSensorCard(
                    icon: Icons.opacity,
                    title: 'Humidity',
                    value: data != null ? '${data.humidity.toStringAsFixed(1)}%' : 'N/A',
                    color: isOnline ? Colors.blue.shade600 : Colors.grey,
                    isOnline: isOnline,
                    type: 'humidity',
                    percentage: data?.humidity ?? 0,
                  ),
                  AnimatedSensorCard(
                    icon: Icons.eco,
                    title: 'Plant Status',
                    value: data != null ? _getMoistureStatus(data.soilMoisture) : 'NO_DATA',
                    color: data != null && isOnline ? _getMoistureColor(data.soilMoisture) : Colors.grey,
                    isOnline: isOnline,
                    type: 'status',
                    percentage: data?.soilMoisture ?? 0,
                  ),
                ],
              );
            },
          ),
        ],
      );
    },
  );
}

  // Add this helper method for status colors
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'DRY':
        return Colors.red;
      case 'MOIST':
        return Colors.green;
      case 'WET':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMonitoringCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 1, // Reduced from 2
      child: Container(
        padding: const EdgeInsets.all(6), // Reduced from 8
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6), // Reduced from 8
          border: Border.all(
              color: color.withOpacity(0.5), width: 1), // Thinner border
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color), // Reduced from 28
            const SizedBox(height: 2), // Reduced from 4
            Text(
              title,
              style: const TextStyle(
                fontSize: 10, // Reduced from 12
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1), // Reduced from 2
            Text(
              value,
              style: TextStyle(
                fontSize: 14, // Reduced from 16
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoistureCard(Map<String, dynamic>? data) {
    final rawMoisture = data?['moisture'] ?? 0;
    // Use the raw moisture value directly as it's already a percentage from ESP32
    final moisturePercentage = rawMoisture.toDouble();
    final String status = _getMoistureStatus(moisturePercentage);
    final Color statusColor = _getMoistureColor(moisturePercentage);

    return _buildSensorCard(
      'Soil Moisture',
      '${moisturePercentage.toStringAsFixed(1)}%',
      status,
      statusColor,
      Icons.water_drop,
      [Colors.blue.shade200, Colors.blue.shade400],
    );
  }

  // Update the moisture status logic to be consistent
  String _getMoistureStatus(num percent) {
    if (percent <= 0) return 'SENSOR ERROR'; // Sensor disconnected or faulty
    if (percent < 40) return 'DRY'; // Needs watering
    if (percent < 70) return 'HUMID'; // Moist soil
    return 'WET'; // Fully wet or in water
  }

  Color _getMoistureColor(num percent) {
    if (percent <= 0) return Colors.red; // Sensor error
    if (percent < 40) return Colors.orange; // Dry
    if (percent < 70) return Colors.blue; // Humid
    return Colors.green; // Wet
  }

  Widget _buildWateringSchedule() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Schedules',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    Provider.of<ScheduleProvider>(context, listen: false)
                        .refreshSchedules(enabled: true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<ScheduleProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter only enabled schedules
                final enabledSchedules = provider.schedules
                    .where((schedule) => schedule.enabled)
                    .toList();

                if (enabledSchedules.isEmpty) {
                  return const Center(
                    child: Text('No active schedules',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: enabledSchedules.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final schedule = enabledSchedules[index];
                    final isWatering = schedule.type == 'watering';
                    final timeStr = schedule.time;
                    final isPM = int.parse(timeStr.split(':')[0]) >= 12;
                    final hour = int.parse(timeStr.split(':')[0]) % 12;
                    final minute = timeStr.split(':')[1];
                    final formattedTime =
                        '${hour == 0 ? 12 : hour}:$minute ${isPM ? 'PM' : 'AM'}';

                    return Row(
                      children: [
                        Icon(
                          isWatering ? Icons.water_drop : Icons.grass,
                          color: isWatering ? Colors.blue : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule.label ??
                                    (isWatering ? 'Watering' : 'Fertilizing'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isWatering
                                    ? 'Every ${schedule.days.join(", ")}'
                                    : 'Monthly on day${schedule.calendarDays!.length > 1 ? "s" : ""} ${schedule.calendarDays!.join(", ")}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formattedTime,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorChart(PlantData data) {
    if (!data.isOnline) {
      return Card(
        child: SizedBox(
          height: 250,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.signal_wifi_off,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Sensors Offline',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sensor Readings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildEnhancedLegendItem(
                    'Moisture',
                    '${data.soilMoisture.toStringAsFixed(1)}%',
                    Colors.blue.shade400,
                  ),
                  const SizedBox(width: 16),
                  _buildEnhancedLegendItem(
                    'Humidity',
                    '${data.humidity.toStringAsFixed(1)}%',
                    Colors.green.shade400,
                  ),
                  const SizedBox(width: 16),
                  _buildEnhancedLegendItem(
                    'Temperature',
                    '${data.temperature.toStringAsFixed(1)}°C',
                    Colors.orange.shade400,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Theme.of(context).cardColor.withOpacity(0.8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          String label = '';
                          Color color = Colors.blue;
                          switch (spot.x.toInt()) {
                            case 0:
                              label = 'Moisture: ${spot.y.toStringAsFixed(1)}%';
                              color = Colors.blue.shade400;
                              break;
                            case 1:
                              label = 'Humidity: ${spot.y.toStringAsFixed(1)}%';
                              color = Colors.green.shade400;
                              break;
                            case 2:
                              label = 'Temp: ${spot.y.toStringAsFixed(1)}°C';
                              color = Colors.orange.shade400;
                              break;
                          }
                          return LineTooltipItem(
                            label,
                            TextStyle(
                                color: color, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 20,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          String text = '';
                          switch (value.toInt()) {
                            case 0:
                              text = 'Moisture';
                              break;
                            case 1:
                              text = 'Humidity';
                              break;
                            case 2:
                              text = 'Temp';
                              break;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              text,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: -0.5,
                  maxX: 2.5,
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        FlSpot(0, data.soilMoisture),
                        FlSpot(1, data.humidity),
                        FlSpot(2, data.temperature),
                      ],
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade400,
                          Colors.green.shade400,
                          Colors.orange.shade400,
                        ],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          Color dotColor;
                          switch (index) {
                            case 0:
                              dotColor = Colors.blue.shade400;
                              break;
                            case 1:
                              dotColor = Colors.green.shade400;
                              break;
                            case 2:
                              dotColor = Colors.orange.shade400;
                              break;
                            default:
                              dotColor = Colors.blue.shade400;
                          }
                          return FlDotCirclePainter(
                            radius: 6,
                            color: Theme.of(context).cardColor,
                            strokeWidth: 3,
                            strokeColor: dotColor,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade400.withOpacity(0.2),
                            Colors.green.shade400.withOpacity(0.2),
                            Colors.orange.shade400.withOpacity(0.2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedLegendItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(String title, String value, String status,
      Color statusColor, IconData icon, List<Color> gradientColors,
      [PlantData? data] // Add optional PlantData parameter
      ) {
    return Stack(
      children: [
        Card(
          elevation: 1,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 9,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (data != null &&
            !data.isOnline) // Check if data exists and is offline
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  'OFFLINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

