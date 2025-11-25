import 'dart:convert'; // added for jsonDecode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype/providers/auth_provider.dart';
import 'package:prototype/services/api_service.dart';

// Remove unused modular view imports
import 'package:prototype/screens/audit_log_screen.dart';
import 'package:prototype/screens/profile_screen.dart';
import 'package:prototype/screens/reports_screen.dart';
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
    setState(() => _selectedIndex = 3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final userRole = authProvider.user?['role'] ?? 'user';
          if (userRole != 'admin') {
            return _buildAccessDeniedScreen(context);
          }

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
        child: Row(
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
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
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
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You do not have permission to access this page.',
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _onLogout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return DashboardView();
      case 1:
        return UsersManagementView();
      case 2:
        return const AuditLogScreen();
      case 3:
        return const ProfileScreen();
      default:
        return Center(child: Text('Page $index'));
    }
  }
}
