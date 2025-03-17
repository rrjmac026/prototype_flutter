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
            _buildMonitoringCard(
              icon: Icons.water_drop,
              title: settings.getLocalizedText('Soil Moisture'),
              value: data != null
                  ? '${data.soilMoisture.toStringAsFixed(1)}%'
                  : 'N/A',
              color: Colors.blue,
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
            const Text(
              'Sensor Readings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Add legend row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Moisture', Colors.blue),
                const SizedBox(width: 16),
                _buildLegendItem('Humidity', Colors.green),
                const SizedBox(width: 16),
                _buildLegendItem('Temperature', Colors.orange),
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
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value == 1) return const Text('Moisture');
                          if (value == 2) return const Text('Humidity');
                          if (value == 3) return const Text('Temp');
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        FlSpot(1, data.soilMoisture),
                        FlSpot(2, data.humidity),
                        FlSpot(3, data.temperature),
                      ],
                      isCurved: true,
                      color: Colors.blue,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    // Add separate lines for humidity and temperature
                    LineChartBarData(
                      spots: [
                        FlSpot(1, 0),
                        FlSpot(2, data.humidity),
                        FlSpot(3, 0),
                      ],
                      isCurved: true,
                      color: Colors.green,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: [
                        FlSpot(1, 0),
                        FlSpot(2, 0),
                        FlSpot(3, data.temperature),
                      ],
                      isCurved: true,
                      color: Colors.orange,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  minY: 0,
                  maxY: 100,
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
}
