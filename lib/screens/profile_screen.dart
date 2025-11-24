import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prototype/providers/theme_provider.dart';
import 'package:prototype/providers/settings_provider.dart';
import 'package:prototype/providers/user_provider.dart';
import 'package:prototype/providers/auth_provider.dart';
import 'package:prototype/services/auth_service.dart';
import 'package:prototype/utils/audit_logger.dart';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prototype/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedLanguage = 'English';
  bool _notificationsEnabled = true;
  String _username = 'User';
  String _bio = 'Plant Enthusiast';
  File? _profileImage;
  String? _profileImagePath;
  String? _userId;
  List<Map<String, dynamic>> _alerts = [];
  Timer? _alertsTimer;
  DateTimeRange? _selectedDateRange;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeUserProfile();
    _logProfileAccess();
  }

  Future<void> _initializeUserProfile() async {
    // Get current user ID
    _userId = await _authService.getCurrentUserId();
    
    // Get user data from AuthProvider
    final authUser = context.read<AuthProvider>().user;
    if (authUser != null) {
      _username = authUser['username'] ?? authUser['displayName'] ?? 'User';
    }
    
    // Load user-specific profile data
    await _loadProfileData();
  }

  Future<void> _logProfileAccess() async {
    final userRole = context.read<AuthProvider>().user?['role'] ?? 'user';
    await AuditLogger.logUserAction(
      'profile_access',
      'User accessed profile screen (role: $userRole)',
    );
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (_userId == null) {
      setState(() {
        _selectedLanguage = prefs.getString('language') ?? 'English';
        _notificationsEnabled = prefs.getBool('notifications') ?? true;
        _bio = prefs.getString('bio') ?? 'Plant Enthusiast';
      });
      return;
    }

    // Load user-specific data using userId as key prefix
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'English';
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _bio = prefs.getString('user_${_userId}_bio') ?? 'Plant Enthusiast';
      _profileImagePath = prefs.getString('user_${_userId}_profileImagePath');
      if (_profileImagePath != null) {
        _profileImage = File(_profileImagePath!);
      }
    });
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _selectedLanguage);
    await prefs.setBool('notifications', _notificationsEnabled);
    
    if (_userId != null) {
      // Save user-specific data
      await prefs.setString('user_${_userId}_bio', _bio);
      if (_profileImagePath != null) {
        await prefs.setString('user_${_userId}_profileImagePath', _profileImagePath!);
      } else {
        await prefs.remove('user_${_userId}_profileImagePath');
      }
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
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Name (from account)',
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
        _bio = bioController.text;
      });
      await _saveProfileData();
      await AuditLogger.logUserAction(
        'profile_edit',
        'User updated profile information',
      );
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
                    await AuditLogger.logUserAction(
                      'profile_photo_update',
                      'User updated profile photo (camera)',
                    );
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
                    await AuditLogger.logUserAction(
                      'profile_photo_update',
                      'User updated profile photo (gallery)',
                    );
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
                    await AuditLogger.logUserAction(
                      'profile_photo_remove',
                      'User removed profile photo',
                    );
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

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final primaryColor = Theme.of(context).colorScheme.primary;
      final accentColor = Theme.of(context).colorScheme.secondary;

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
        Navigator.pop(context);
        await AuditLogger.logUserAction(
          'report_generated',
          'User generated report for ${DateFormat('MMM d').format(pickedRange.start)} - ${DateFormat('MMM d').format(pickedRange.end)}',
        );

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

  Future<void> _handleLogout() async {
    try {
      await AuditLogger.logUserAction(
        'logout',
        'User logged out',
      );
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = context.read<AuthProvider>().user?['role'] ?? 'user';
    final isAdmin = userRole == 'admin';

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
                    colors: isAdmin
                        ? [Colors.purple.shade400, Colors.indigo.shade400]
                        : [Colors.green.shade400, Colors.teal.shade400],
                  ),
                ),
                child: _buildProfileHeader(isAdmin),
              ),
            ),
          ),
          SliverFillRemaining(
            child: SingleChildScrollView(
              child: _buildRoleSpecificContent(isAdmin),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool isAdmin) {
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
                      ? Icon(
                          isAdmin ? Icons.admin_panel_settings : Icons.person,
                          size: 50,
                        )
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
                    Row(
                      children: [
                        Text(
                          _username,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (isAdmin)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildRoleSpecificContent(bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (isAdmin) ...[
            _buildAdminCard(),
            const SizedBox(height: 16),
          ],
          _buildGenerateReportCard(),
          const SizedBox(height: 16),
          _buildSettingsSection(context),
        ],
      ),
    );
  }

  Widget _buildAdminCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.shade200),
      ),
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.admin_panel_settings,
                color: Colors.purple.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Administrator Access',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You have full access to admin features',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade600,
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

  Widget _buildGenerateReportCard() {
    return Card(
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
    );
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
                        AuditLogger.logUserAction(
                          'theme_changed',
                          'User changed theme to ${value ? 'dark' : 'light'} mode',
                        );
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
                        if (value != null) {
                          settings.setLanguage(value);
                          AuditLogger.logUserAction(
                            'language_changed',
                            'User changed language to ${value.name}',
                          );
                        }
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
                        if (value != null) {
                          settings.setTempUnit(value);
                          AuditLogger.logUserAction(
                            'temp_unit_changed',
                            'User changed temperature unit to ${value.name}',
                          );
                        }
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
                      onChanged: (value) {
                        settings.setNotifications(
                            value, settings.messageEnabled);
                        AuditLogger.logUserAction(
                          'push_notifications_changed',
                          'User toggled push notifications to $value',
                        );
                      },
                    ),
                  ),
                  _buildSettingsTile(
                    icon: Icons.message_outlined,
                    title: settings.getLocalizedText('Message Notifications'),
                    trailing: Switch.adaptive(
                      value: settings.messageEnabled,
                      onChanged: (value) {
                        settings.setNotifications(
                            settings.pushEnabled, value);
                        AuditLogger.logUserAction(
                          'message_notifications_changed',
                          'User toggled message notifications to $value',
                        );
                      },
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Account',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
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

  @override
  void dispose() {
    _alertsTimer?.cancel();
    super.dispose();
  }
}