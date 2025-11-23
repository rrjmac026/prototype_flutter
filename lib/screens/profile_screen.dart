import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prototype/providers/theme_provider.dart';
import 'package:prototype/providers/settings_provider.dart';
import 'package:prototype/providers/user_provider.dart';
import 'dart:io';
import 'dart:async'; // Add this for Timer
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prototype/services/api_service.dart';
import 'package:intl/intl.dart'; // Add this for DateFormat
import 'package:path_provider/path_provider.dart'; // Add this for temporary directory
import 'package:url_launcher/url_launcher.dart'; // Add this for launching URLs
import 'dart:convert'; // Add this for jsonEncode

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedLanguage = 'English';
  bool _notificationsEnabled = true;
  String _username = 'Jam Mac';
  String _bio = 'Plant Enthusiast';
  File? _profileImage;
  String? _profileImagePath; // Add this line
  List<Map<String, dynamic>> _alerts = [];
  Timer? _alertsTimer; // Add this
  DateTimeRange? _selectedDateRange; // Add this

  @override
  void initState() {
    super.initState();
    _loadProfileData();
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
    final TextEditingController nameController =
        TextEditingController(text: _username);
    final TextEditingController bioController =
        TextEditingController(text: _bio);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _username = nameController.text;
        _bio = bioController.text;
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
                    await _saveProfileData(); // Save after updating image
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
                    await _saveProfileData(); // Save after updating image
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
                    await _saveProfileData(); // Save after removing image
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateReport() async {
    try {
      // Show date picker first
      final pickedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now(),
        initialDateRange: _selectedDateRange ??
            DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              primaryColor: Theme.of(context).colorScheme.primary,
              colorScheme: Theme.of(context).colorScheme,
            ),
            child: child!,
          );
        },
      );

      if (pickedRange == null) return;
      _selectedDateRange = pickedRange;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Generating report for:\n${DateFormat('MMM d').format(pickedRange.start)} - ${DateFormat('MMM d').format(pickedRange.end)}',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Get theme colors and styling parameters
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final primaryColor = Theme.of(context).colorScheme.primary;
      final accentColor = Theme.of(context).colorScheme.secondary;

      // Build URL with enhanced styling parameters
      final url = Uri.parse('${ApiService.baseUrl}/reports?' +
          'plantId=${ApiService.defaultPlantId}&' +
          'start=${pickedRange.start.toIso8601String()}&' +
          'end=${pickedRange.end.toIso8601String()}&' +
          'format=pdf&' +
          'style=' +
          Uri.encodeComponent(jsonEncode({
            'colors': {
              'primary':
                  '#${primaryColor.value.toRadixString(16).substring(2)}',
              'accent': '#${accentColor.value.toRadixString(16).substring(2)}',
              'background': isDark ? '#121212' : '#ffffff',
              'text': isDark ? '#ffffff' : '#000000',
              'headerBg': isDark ? '#1E1E1E' : '#f5f5f5',
              'chartLine':
                  '#${Colors.blue.shade400.value.toRadixString(16).substring(2)}',
              'chartGrid': isDark ? '#303030' : '#e0e0e0',
            },
            'fonts': {'title': 'Roboto', 'body': 'Arial'},
            'spacing': {'margin': 40, 'padding': 20},
            'header': {
              'logo': true,
              'dateFormat': 'MMM d, y HH:mm',
              'showPageNumbers': true
            }
          })));

      if (context.mounted) {
        Navigator.pop(context); // Hide loading dialog

        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch report URL');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    }
  }

  Widget _buildReportSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text('• $item'),
            )),
      ],
    );
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
            child: SingleChildScrollView(child: _buildOverviewTab()),
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
          Stack(
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
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _editProfile,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
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
                const SizedBox(width: 8),
                const Icon(Icons.edit, color: Colors.white70, size: 16),
              ],
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
          // Generate Report Card
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

  @override
  void dispose() {
    _alertsTimer?.cancel(); // Add this
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