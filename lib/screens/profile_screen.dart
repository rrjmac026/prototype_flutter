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
    try {
      // Get current user ID with retry logic
      _userId = await _authService.getCurrentUserId();
      
      // If still null, try to get from AuthProvider
      if (_userId == null && mounted) {
        final authUser = context.read<AuthProvider>().user;
        _userId = authUser?['uid'] ?? authUser?['id'];
      }
      
      // Get user data from AuthProvider
      if (mounted) {
        final authUser = context.read<AuthProvider>().user;
        if (authUser != null) {
          final newUsername = authUser['username'] ?? authUser['displayName'] ?? 'User';
          if (mounted) {
            setState(() {
              _username = newUsername;
            });
          }
        }
      }
      
      // Load user-specific profile data
      await _loadProfileData();
    } catch (e) {
      print('Error initializing user profile: $e');
      // Don't crash the app, just log the error
      if (mounted) {
        // Optionally show a subtle error to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load some profile data'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
    final storedImagePath = prefs.getString('user_${_userId}_profileImagePath');
    
    File? loadedImage;
    if (storedImagePath != null) {
      final imageFile = File(storedImagePath);
      // Check if file exists and is accessible
      try {
        if (await imageFile.exists()) {
          loadedImage = imageFile;
        } else {
          // File doesn't exist anymore, clear the stored path
          await prefs.remove('user_${_userId}_profileImagePath');
        }
      } catch (e) {
        print('Error loading profile image: $e');
        // Clear invalid path
        await prefs.remove('user_${_userId}_profileImagePath');
      }
    }
    
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'English';
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _bio = prefs.getString('user_${_userId}_bio') ?? 'Plant Enthusiast';
      _profileImage = loadedImage;
      _profileImagePath = loadedImage?.path;
    });
  }

  Future<void> _saveProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', _selectedLanguage);
      await prefs.setBool('notifications', _notificationsEnabled);
      
      if (_userId != null && _userId!.isNotEmpty) {
        // Save user-specific data
        await prefs.setString('user_${_userId}_bio', _bio);
        
        if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
          await prefs.setString('user_${_userId}_profileImagePath', _profileImagePath!);
          print('Saved profile image path: $_profileImagePath');
        } else {
          await prefs.remove('user_${_userId}_profileImagePath');
          print('Removed profile image path');
        }
      }
    } catch (e) {
      print('Error saving profile data: $e');
      // Don't throw - just log the error
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
    
    // Don't use context.read inside the bottom sheet callbacks
    final settingsProvider = context.read<SettingsProvider>();
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(settingsProvider.getLocalizedText('Take Photo')),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  try {
                    final XFile? photo = await picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 512,
                      maxHeight: 512,
                      imageQuality: 85,
                    );
                    if (photo != null && mounted) {
                      await _saveImageToLocalStorage(photo);
                      await AuditLogger.logUserAction(
                        'profile_photo_update',
                        'User updated profile photo (camera)',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to capture photo: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(settingsProvider.getLocalizedText('Choose from Gallery')),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  try {
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 512,
                      maxHeight: 512,
                      imageQuality: 85,
                    );
                    if (image != null && mounted) {
                      await _saveImageToLocalStorage(image);
                      await AuditLogger.logUserAction(
                        'profile_photo_update',
                        'User updated profile photo (gallery)',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to select photo: $e')),
                      );
                    }
                  }
                },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(settingsProvider.getLocalizedText('Remove Photo')),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    try {
                      // Delete the old file if it exists
                      if (_profileImagePath != null) {
                        final oldFile = File(_profileImagePath!);
                        if (await oldFile.exists()) {
                          await oldFile.delete();
                        }
                      }
                      
                      if (mounted) {
                        setState(() {
                          _profileImage = null;
                          _profileImagePath = null;
                        });
                        await _saveProfileData();
                        await AuditLogger.logUserAction(
                          'profile_photo_remove',
                          'User removed profile photo',
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to remove photo: $e')),
                        );
                      }
                    }
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
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AuditLogger.logUserAction(
        'logout',
        'User logged out',
      );
      
      // Clear the userId to prevent any further operations
      setState(() {
        _userId = null;
        _profileImage = null;
        _profileImagePath = null;
      });
      
      await context.read<AuthProvider>().logout();
      
      if (!mounted) return;
      
      // Use pushNamedAndRemoveUntil to clear the navigation stack
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      print('Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  Future<void> _checkAuthState() async {
      try {
        final authProvider = context.read<AuthProvider>();
        final user = authProvider.user;
        final userId = await _authService.getCurrentUserId();
        
        print('=== AUTH STATE CHECK ===');
        print('Local _userId: $_userId');
        print('AuthService userId: $userId');
        print('AuthProvider user: ${user != null ? user['username'] ?? user['email'] : 'NULL'}');
        print('AuthProvider role: ${user?['role']}');
        print('Profile image path: $_profileImagePath');
        print('Profile image exists: ${_profileImage?.existsSync()}');
        print('=======================');
        
        // If there's a mismatch, something went wrong
        if (user == null && _userId != null) {
          print('WARNING: User is null but userId exists - possible session issue');
          // Don't auto-logout, let user try to continue
        }
        
        if (userId != _userId && userId != null) {
          print('WARNING: userId mismatch detected');
          setState(() {
            _userId = userId;
          });
          await _loadProfileData();
        }
      } catch (e) {
        print('Error checking auth state: $e');
      }
    }

    Future<void> _saveImageToLocalStorage(XFile imageFile) async {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Uploading photo...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }
      
      try {
        // Ensure we have a userId
        String? currentUserId = _userId;
        if (currentUserId == null || currentUserId.isEmpty) {
          currentUserId = await _authService.getCurrentUserId();
          if (currentUserId == null || currentUserId.isEmpty) {
            throw Exception('User session expired. Please log in again.');
          }
          _userId = currentUserId;
        }

        // Get application documents directory
        final appDir = await getApplicationDocumentsDirectory();
        
        // Create profiles subdirectory
        final profilesDir = Directory('${appDir.path}/profiles');
        if (!await profilesDir.exists()) {
          await profilesDir.create(recursive: true);
        }
        
        // Create a unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'profile_${currentUserId}_$timestamp.jpg';
        final newPath = '${profilesDir.path}/$fileName';
        
        // Read and write the image
        final bytes = await imageFile.readAsBytes();
        final newFile = File(newPath);
        await newFile.writeAsBytes(bytes, flush: true);
        
        // Verify file was created
        if (!await newFile.exists()) {
          throw Exception('Failed to save image file');
        }
        
        print('Image saved to: $newPath');
        
        // Delete old profile image AFTER new one is saved successfully
        if (_profileImagePath != null && 
            _profileImagePath!.isNotEmpty && 
            _profileImagePath != newPath) {
          try {
            final oldFile = File(_profileImagePath!);
            if (await oldFile.exists()) {
              await oldFile.delete();
              print('Old image deleted: $_profileImagePath');
            }
          } catch (e) {
            print('Failed to delete old image (non-critical): $e');
          }
        }
        
        // Update state
        if (mounted) {
          setState(() {
            _profileImage = newFile;
            _profileImagePath = newPath;
          });
          
          // Save to SharedPreferences
          await _saveProfileData();
          
          // Hide loading and show success
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 16),
                  Text('Profile photo updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error in _saveImageToLocalStorage: $e');
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(child: Text('Failed to save photo: $e')),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
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
            expandedHeight: 240, // Increased from 200 to 240
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Profile Picture with Edit Button
            Stack(
              children: [
                GestureDetector(
                  onTap: _handleImageSelection,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _profileImage != null && _profileImage!.existsSync()
                          ? FileImage(_profileImage!)
                          : null,
                      child: _profileImage == null || !_profileImage!.existsSync()
                          ? Icon(
                              isAdmin ? Icons.admin_panel_settings : Icons.person,
                              size: 50,
                              color: Colors.grey.shade600,
                            )
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _handleImageSelection,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Name and Bio Section with proper overflow handling
            GestureDetector(
              onTap: _editProfile,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name with Admin Badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _username,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade600,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Bio with Edit Icon
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _bio,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.edit,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ],
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