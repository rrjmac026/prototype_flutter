import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prototype/providers/theme_provider.dart';
import 'package:prototype/providers/settings_provider.dart';
import 'package:prototype/providers/user_provider.dart';
import 'package:prototype/providers/plant_data_provider.dart';
import 'package:prototype/models/plant_data.dart';
import 'package:prototype/models/message.dart';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prototype/services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  String _selectedLanguage = 'English';
  bool _notificationsEnabled = true;
  String _username = 'Jam Mac';
  String _bio = 'Plant Enthusiast';
  File? _profileImage;
  String? _profileImagePath;
  late TabController _tabController;
  List<Map<String, dynamic>> _alerts = [];
  Timer? _alertsTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
    _startAlertsCheck();
  }

  List<PlantData> get _recentReadings =>
      Provider.of<PlantDataProvider>(context, listen: false).historicalReadings;

  void _startAlertsCheck() {
    _alertsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAlerts();
    });
  }

  void _checkAlerts() {
    final provider = Provider.of<PlantDataProvider>(context, listen: false);
    final data = provider.latestData;

    if (data != null) {
      if (data.soilMoisture < 20) {
        setState(() {
          _alerts.insert(0, {
            'type': 'warning',
            'message': 'Low soil moisture detected (${data.soilMoisture}%)',
            'time': DateTime.now(),
          });
        });
      }

      if (data.temperature > 30) {
        setState(() {
          _alerts.insert(0, {
            'type': 'warning',
            'message': 'High temperature detected (${data.temperature}°C)',
            'time': DateTime.now(),
          });
        });
      }

      if (data.humidity < 40) {
        setState(() {
          _alerts.insert(0, {
            'type': 'warning',
            'message': 'Low humidity detected (${data.humidity}%)',
            'time': DateTime.now(),
          });
        });
      }

      if (_alerts.length > 10) {
        setState(() {
          _alerts = _alerts.take(10).toList();
        });
      }
    }
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'English';
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _username = Provider.of<UserProvider>(context, listen: false).username;
      _bio = prefs.getString('bio') ?? 'Plant Enthusiast';
      _profileImagePath = prefs.getString('profileImagePath');
      if (_profileImagePath != null) {
        _profileImage = File(_profileImagePath!);
      }
    });
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _selectedLanguage);
    await prefs.setBool('notifications', _notificationsEnabled);
    await Provider.of<UserProvider>(context, listen: false)
        .setUsername(_username);
    await prefs.setString('bio', _bio);
    if (_profileImagePath != null) {
      await prefs.setString('profileImagePath', _profileImagePath!);
    } else {
      await prefs.remove('profileImagePath');
    }
  }

  Future<void> _editProfile() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: _username),
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (value) => _username = value,
            ),
            TextField(
              controller: TextEditingController(text: _bio),
              decoration: const InputDecoration(labelText: 'Bio'),
              onChanged: (value) => _bio = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'username': _username,
                'bio': _bio,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _username = result['username']!;
        _bio = result['bio']!;
      });
      await _saveProfileData();
    }
  }

  Future<void> _handleImageSelection() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(context
                    .read<SettingsProvider>()
                    .getLocalizedText('Take Photo')),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? photo =
                      await picker.pickImage(source: ImageSource.camera);
                  if (photo != null) {
                    setState(() {
                      _profileImage = File(photo.path);
                      _profileImagePath = photo.path;
                    });
                    await _saveProfileData();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(context
                    .read<SettingsProvider>()
                    .getLocalizedText('Choose from Gallery')),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() {
                      _profileImage = File(image.path);
                      _profileImagePath = image.path;
                    });
                    await _saveProfileData();
                  }
                },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(context
                      .read<SettingsProvider>()
                      .getLocalizedText('Remove Photo')),
                  onTap: () async {
                    Navigator.pop(context);
                    setState(() {
                      _profileImage = null;
                      _profileImagePath = null;
                    });
                    await _saveProfileData();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareFiles(
        [filePath],
        text: 'Plant Report',
        subject: 'Plant Monitoring Report',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openFile(String filePath) async {
    await _shareFile(filePath);
  }

  Future<DateTimeRange?> _showDateRangePicker() async {
    final initialDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    return await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: Theme.of(context).colorScheme.primary,
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _generateReport() async {
    // Show date range picker first
    final dateRange = await _showDateRangePicker();
    if (dateRange == null) return;

    int retryCount = 0;
    const maxRetries = 3;
    late BuildContext dialogContext;

    while (retryCount < maxRetries) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            dialogContext = ctx;
            return Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        retryCount > 0
                            ? 'Retrying... (${retryCount + 1}/$maxRetries)'
                            : 'Generating report...',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'From: ${DateFormat('MMM dd, yyyy').format(dateRange.start)}\n'
                        'To: ${DateFormat('MMM dd, yyyy').format(dateRange.end)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        // Convert local time to UTC for the API
        final startUtc = DateTime.utc(
          dateRange.start.year,
          dateRange.start.month,
          dateRange.start.day,
        );
        final endUtc = DateTime.utc(
          dateRange.end.year,
          dateRange.end.month,
          dateRange.end.day,
          23, 59, 59, // End of day
        );

        final reportData = await ApiService().generateReport(
          ApiService.defaultPlantId,
          startUtc,
          endUtc,
        );

        if (!context.mounted) return;
        Navigator.of(dialogContext).pop();

        final tempDir = await getTemporaryDirectory();
        final fileName =
            'plant_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(reportData);

        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade400),
                const SizedBox(width: 8),
                const Text('Success'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Report generated successfully!'),
                const SizedBox(height: 8),
                Text(
                  'Saved as: $fileName',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => _shareFile(file.path),
                child: const Text('Share Report'),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Report saved to: ${file.path}'),
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'Share',
                        onPressed: () => _shareFile(file.path),
                      ),
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      } catch (e) {
        if (!context.mounted) return;
        Navigator.of(dialogContext).pop();

        retryCount++;
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        final canRetry =
            !errorMessage.contains('Empty PDF') && retryCount < maxRetries;

        if (canRetry) {
          final shouldRetry = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade400),
                  const SizedBox(width: 8),
                  Text('Error (${retryCount + 1}/$maxRetries)'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(errorMessage),
                  const SizedBox(height: 8),
                  const Text('Would you like to retry?'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
          if (shouldRetry ?? false) continue;
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400),
                const SizedBox(width: 8),
                const Text('Error'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                if (retryCount >= maxRetries) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Maximum retry attempts reached',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.teal.shade400],
                  ),
                ),
                child: _buildProfileHeader(),
              ),
            ),
          ),
          SliverFillRemaining(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Readings'),
                    Tab(text: 'Alerts'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      SingleChildScrollView(child: _buildOverviewTab()),
                      SingleChildScrollView(child: _buildReadingsTab()),
                      SingleChildScrollView(child: _buildAlertsTab()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _handleImageSelection,
            child: CircleAvatar(
              radius: 50,
              backgroundImage:
                  _profileImage != null ? FileImage(_profileImage!) : null,
              child: _profileImage == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            _bio,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatCard('Total Plants', '1'),
          _buildStatCard('Active Alerts', _alerts.length.toString()),
          Card(
            child: InkWell(
              onTap: _generateReport,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generate Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Download a detailed report of your plant data',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsSection(context),
        ],
      ),
    );
  }

  Widget _buildReadingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Consumer<PlantDataProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sensor Readings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      provider.refreshData();
                    },
                  ),
                ],
              ),
              if (provider.latestData != null) ...[
                _buildReadingsChart(),
                const SizedBox(height: 16),
                ..._buildReadingsList(),
              ] else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlertsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (context, index) => _buildAlertCard(_alerts[index]),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReadingsList() {
    return _recentReadings.map((reading) {
      return Card(
        child: ListTile(
          title: Text('Moisture: ${reading.soilMoisture}%'),
          subtitle: Text(
            'Temperature: ${reading.temperature}°C | Humidity: ${reading.humidity}%',
          ),
          trailing: Text(
            TimeOfDay.fromDateTime(reading.timestamp).format(context),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.warning, color: Colors.orange),
        title: Text(alert['message']),
        subtitle: Text(
          TimeOfDay.fromDateTime(alert['time']).format(context),
        ),
      ),
    );
  }

  Widget _buildReadingsChart() {
    if (_recentReadings.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sensor Reading History',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
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
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 10,
                    verticalInterval: 1,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value % 1 == 0) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '${_recentReadings.length - value.toInt()}m',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                              fontSize: 12,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (_recentReadings.length - 1).toDouble(),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    _createLineBarsData(_recentReadings,
                        (reading) => reading.soilMoisture, Colors.blue),
                    _createLineBarsData(_recentReadings,
                        (reading) => reading.humidity, Colors.green),
                    _createLineBarsData(_recentReadings,
                        (reading) => reading.temperature, Colors.orange),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  LineChartBarData _createLineBarsData(
    List<PlantData> readings,
    double Function(PlantData) getValue,
    Color color,
  ) {
    return LineChartBarData(
      spots: readings
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), getValue(e.value)))
          .toList(),
      isCurved: true,
      color: color,
      dotData: const FlDotData(show: true),
    );
  }

  @override
  void dispose() {
    _alertsTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildSettingsSection(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                settings.getLocalizedText('Settings'),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingsGroup(
                title: 'Preferences',
                icon: Icons.palette_outlined,
                children: [
                  _buildSettingsTile(
                    icon: Icons.dark_mode,
                    title: 'Dark Mode',
                    trailing: Switch.adaptive(
                      value: Provider.of<ThemeProvider>(context).themeMode ==
                          ThemeMode.dark,
                      onChanged: (value) {
                        Provider.of<ThemeProvider>(context, listen: false)
                            .toggleTheme(value);
                      },
                    ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.language,
                    title: settings.getLocalizedText('Language'),
                    trailing: _buildDropdownButton<Language>(
                      value: settings.language,
                      items: Language.values.map((lang) {
                        return DropdownMenuItem(
                          value: lang,
                          child: Text(lang.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) settings.setLanguage(value);
                      },
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              _buildSettingsGroup(
                title: 'Measurements',
                icon: Icons.speed_outlined,
                children: [
                  _buildSettingsTile(
                    icon: Icons.thermostat,
                    title: settings.getLocalizedText('Temperature Unit'),
                    trailing: _buildDropdownButton<TempUnit>(
                      value: settings.tempUnit,
                      items: TempUnit.values.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) settings.setTempUnit(value);
                      },
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              _buildSettingsGroup(
                title: 'Notifications',
                icon: Icons.notifications_outlined,
                children: [
                  _buildSettingsTile(
                    icon: Icons.notification_important_outlined,
                    title: settings.getLocalizedText('Push Notifications'),
                    trailing: Switch.adaptive(
                      value: settings.pushEnabled,
                      onChanged: (value) => settings.setNotifications(
                          value, settings.messageEnabled),
                    ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.message_outlined,
                    title: settings.getLocalizedText('Message Notifications'),
                    trailing: Switch.adaptive(
                      value: settings.messageEnabled,
                      onChanged: (value) => settings.setNotifications(
                          settings.pushEnabled, value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
      dense: true,
    );
  }

  Widget _buildDropdownButton<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: Theme.of(context).colorScheme.surface,
        icon: Icon(
          Icons.arrow_drop_down,
          color: Theme.of(context).colorScheme.primary,
        ),
        items: items,
        onChanged: onChanged,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
