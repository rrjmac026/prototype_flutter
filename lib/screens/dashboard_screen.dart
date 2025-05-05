import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype/providers/plant_data_provider.dart';
import 'package:prototype/providers/settings_provider.dart'; // Add this import
import 'package:prototype/models/plant_data.dart';
import 'package:prototype/providers/user_provider.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantDataProvider>().init();
    });

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

          // Wrap content in StreamBuilder for real-time updates
          return StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 2)),
            builder: (context, snapshot) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny, color: Colors.yellow.shade300, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<UserProvider>(
                      builder: (context, userProvider, child) => Text(
                        'Good Morning, ${userProvider.username}!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringGrid(PlantData? data) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 6, // Reduced from 8
          crossAxisSpacing: 6, // Reduced from 8
          childAspectRatio: 1.6, // Increased from 1.4 to make cards shorter
          padding: const EdgeInsets.symmetric(horizontal: 2), // Reduced padding
          children: [
            _buildMoistureCard(data?.toMap()),
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
              value:
                  data != null ? '${data.humidity.toStringAsFixed(1)}%' : 'N/A',
              color: Colors.green,
            ),
            _buildMonitoringCard(
              icon: Icons.warning_rounded, // Changed from wb_sunny
              title: 'Status',
              value: data?.moistureStatus ?? 'NO_DATA',
              color: _getStatusColor(data?.moistureStatus), // Add status color
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
    final moistureValue = data?['moisture'] ?? 0;
    final String status = _getMoistureStatus(moistureValue);
    final Color statusColor = _getMoistureColor(moistureValue);

    return _buildSensorCard(
      'Soil Moisture',
      moistureValue.toStringAsFixed(0),
      status,
      statusColor,
      Icons.water_drop,
      [Colors.blue.shade200, Colors.blue.shade400],
    );
  }

  String _getMoistureStatus(num value) {
    if (value >= 1000) return 'SENSOR ERROR';
    if (value > 600) return 'DRY SOIL';
    if (value >= 370) return 'HUMID SOIL';
    return 'IN WATER';
  }

  Color _getMoistureColor(num value) {
    if (value >= 1000) return Colors.red;
    if (value > 600) return Colors.orange;
    if (value >= 370) return Colors.blue;
    return Colors.green;
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sensor Readings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Moisture (0-1023)', Colors.blue),
                const SizedBox(width: 16),
                _buildLegendItem('Humidity (%)', Colors.green),
                const SizedBox(width: 16),
                _buildLegendItem('Temperature (°C)', Colors.orange),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
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
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          );
                        },
                        interval: 200, // Adjust interval for better readability
                      ),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    // Moisture line (raw values 0-1023)
                    LineChartBarData(
                      spots: [FlSpot(0, data.soilMoisture)],
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
                  maxY: 1023, // Set max Y to accommodate moisture sensor range
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

  Widget _buildSensorCard(
    String title,
    String value,
    String status,
    Color statusColor,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Card(
      elevation: 1,
      child: Container(
        padding: const EdgeInsets.all(6),
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
          children: [
            Icon(icon, size: 24, color: Colors.white),
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
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
