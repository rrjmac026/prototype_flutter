import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype/providers/plant_data_provider.dart';
import 'package:prototype/providers/settings_provider.dart'; // Add this import
import 'package:prototype/models/plant_data.dart';
import 'package:prototype/providers/user_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Initialize data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantDataProvider>().init();
      // Start auto-refresh timer
      _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) {
          context.read<PlantDataProvider>().refreshData();
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sensors Offline',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Check sensor connections',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 6, // Reduced from 8
              crossAxisSpacing: 6, // Reduced from 8
              childAspectRatio: 1.6, // Increased from 1.4 to make cards shorter
              padding:
                  const EdgeInsets.symmetric(horizontal: 2), // Reduced padding
              children: [
                _buildMonitoringCard(
                  icon: Icons.water_drop,
                  title: 'Soil Moisture',
                  value: isOnline
                      ? '${data?.soilMoisture.toStringAsFixed(1)}%'
                      : 'N/A',
                  color: isOnline
                      ? _getMoistureColor(data?.soilMoisture ?? 0)
                      : Colors.grey,
                ),
                _buildMonitoringCard(
                  icon: Icons.thermostat,
                  title: settings.getLocalizedText('Temperature'),
                  value: data != null
                      ? settings.formatTemperature(data.temperature)
                      : 'N/A',
                  color: Colors.orange,
                ),
                _buildMonitoringCard(
                  icon: Icons.water,
                  title: 'Humidity',
                  value: data != null
                      ? '${data.humidity.toStringAsFixed(1)}%'
                      : 'N/A',
                  color: Colors.green,
                ),
                // Update this section to use the same moisture status logic
                _buildMonitoringCard(
                  icon: Icons.warning_rounded,
                  title: 'Status',
                  value: data != null
                      ? _getMoistureStatus(data.soilMoisture)
                      : 'NO_DATA',
                  color: data != null
                      ? _getMoistureColor(data.soilMoisture)
                      : Colors.grey,
                ),
              ],
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
            const Text(
              'Watering Schedule',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildScheduleItem('Morning', '7:00 AM'),
            const SizedBox(height: 8),
            _buildScheduleItem('Evening', '6:00 PM'),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(String time, String hour) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(time),
        Text(
          hour,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
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

    final moisturePercentage = data.soilMoisture;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(8, 16, 16, 8), // Adjusted right padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('Sensor Readings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Moisture (%)', Colors.blue),
                  const SizedBox(width: 16),
                  _buildLegendItem('Humidity (%)', Colors.green),
                  const SizedBox(width: 16),
                  _buildLegendItem('Temperature (°C)', Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('Value'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32, // Increased reserved size
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 9,
                              ),
                            ),
                          );
                        },
                        interval: 20,
                      ),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    // Moisture line (percentage from server)
                    LineChartBarData(
                      spots: [FlSpot(0, moisturePercentage)],
                      isCurved: true,
                      color: Colors.blue,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    // Humidity line (0-100%)
                    LineChartBarData(
                      spots: [FlSpot(1, data.humidity)],
                      isCurved: true,
                      color: Colors.green,
                      dotData: const FlDotData(show: true),
                    ),
                    // Temperature line (°C)
                    LineChartBarData(
                      spots: [FlSpot(2, data.temperature)],
                      isCurved: true,
                      color: Colors.orange,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  minY: 0,
                  maxY: 100,
                  // Remove margin property
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this helper method for legend items
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 4,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
