import 'dart:convert'; // added for jsonDecode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype/providers/auth_provider.dart';
import 'package:prototype/services/api_service.dart';

// Remove unused modular view imports
import 'package:prototype/screens/audit_log_screen.dart';
import 'package:prototype/screens/profile_screen.dart';
import 'package:prototype/screens/reports_screen.dart';
import 'package:prototype/screens/schedule_screen.dart';
// Add these imports for admin views:
import 'package:prototype/screens/admin/dashboard_view.dart';
import 'package:prototype/screens/admin/users_management_view.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  void _onLogout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _onAccount(BuildContext context) {
    // Instead of navigating, switch to profile tab
    setState(() => _selectedIndex = 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final userRole = authProvider.user?['role'] ?? 'user';
          if (userRole != 'admin') {
            return _buildAccessDeniedScreen(context);
          }

          // Main content area (page content)
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildContent(_selectedIndex),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final items = <Map<String, dynamic>>[
      {'icon': Icons.dashboard, 'label': 'Dashboard'},
      {'icon': Icons.people, 'label': 'Users'},
      {'icon': Icons.schedule, 'label': 'Schedule'},
      {'icon': Icons.description, 'label': 'Audit'},
      {'icon': Icons.account_circle, 'label': 'Profile'},
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // navigation icons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = _selectedIndex == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedIndex = index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: selected
                          ? BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            )
                          : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item['icon'],
                            color: selected ? Colors.green.shade700 : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['label'],
                            style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.green.shade700 : Colors.grey.shade600,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            // action buttons row (Logout only, Account/Profile is now a tab)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _onLogout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDeniedScreen(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 80,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Access Denied',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'You do not have permission to access this page.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade400,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        // DashboardView can remain if you have a custom admin dashboard
        return DashboardView();
      case 1:
        // UsersManagementView can remain if you have a custom admin users view
        return UsersManagementView();
      case 2:
        // Use the shared ScheduleScreen
        return const ScheduleScreen();
      case 3:
        // Use the shared AuditLogScreen
        return const AuditLogScreen();
      case 4:
        // Use the shared ProfileScreen
        return const ProfileScreen();
      default:
        return DashboardView();
    }
  }
}
