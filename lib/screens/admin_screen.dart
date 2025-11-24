import 'dart:convert'; // added for jsonDecode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype/providers/auth_provider.dart';
import 'package:prototype/services/api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _onLogout(context);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('Account'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final userRole = authProvider.user?['role'] ?? 'user';
          if (userRole != 'admin') {
            return _buildAccessDeniedScreen(context);
          }

          return Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                labelType: NavigationRailLabelType.selected,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Dashboard'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people),
                    selectedIcon: Icon(Icons.people),
                    label: Text('Users'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.assessment),
                    selectedIcon: Icon(Icons.assessment),
                    label: Text('Reports'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('Settings'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.description),
                    selectedIcon: Icon(Icons.description),
                    label: Text('Audit Logs'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _buildContent(_selectedIndex),
              ),
            ],
          );
        },
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
        return const _DashboardView();
      case 1:
        return const _UsersManagementView();
      case 2:
        return const _ReportsView();
      case 3:
        return const _SettingsView();
      case 4:
        return const _AuditLogsView();
      default:
        return const _DashboardView();
    }
  }
}

// Dashboard View (simplified, no static numbers)
class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(4, (i) {
              return SizedBox(
                width: 300,
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          [Icons.people, Icons.eco, Icons.health_and_safety, Icons.warning][i],
                          size: 32,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '—', // placeholder for dynamic value
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ['Active Users', 'Total Plants', 'System Health', 'Active Alerts'][i],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.history, size: 32, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('No recent activity yet'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: hook to fetch recent activity
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Refreshing activity...')),
                        );
                      },
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Users Management View (placeholder + ready to hook)
class _UsersManagementView extends StatefulWidget {
  const _UsersManagementView();

  @override
  State<_UsersManagementView> createState() => _UsersManagementViewState();
}

class _UsersManagementViewState extends State<_UsersManagementView> {
  bool _loading = false;
  List<dynamic> _users = [];

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiService.get('/auth/users');
      if (resp.statusCode == 200) {
        final body = resp.body;
        final parsed = body.isNotEmpty ? jsonDecode(body) : null;

        if (parsed is Map && parsed.containsKey('users')) {
          setState(() => _users = List<dynamic>.from(parsed['users']));
        } else if (parsed is List) {
          setState(() => _users = List<dynamic>.from(parsed));
        } else {
          setState(() => _users = []);
        }
      } else if (resp.statusCode == 401) {
        setState(() => _users = []);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unauthorized. Please login again.')),
          );
        }
      } else {
        setState(() => _users = []);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load users: ${resp.statusCode}')),
          );
        }
      }
    } catch (e) {
      setState(() => _users = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'User Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _loading ? null : _loadUsers,
                    icon: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: open add-user dialog (server integration)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add user not implemented')));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add User'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade400),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                const Text('No users loaded'),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _loadUsers, child: const Text('Load Users')),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final email = user['email'] ?? user['mail'] ?? '—';
                              final username = user['username'] ?? user['name'] ?? '—';
                              final role = (user['role'] ?? 'user').toString();
                              return ListTile(
                                leading: CircleAvatar(child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?')),
                                title: Text(username),
                                subtitle: Text(email),
                                trailing: Text(role.toUpperCase()),
                                onTap: () {
                                  // TODO: show user details / actions
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User actions not implemented')));
                                },
                              );
                            },
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reports and Settings and AuditViews simplified placeholders
class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assessment, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              const Text('Reports will appear here'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () {
                // TODO: implement report export / listing
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reports not implemented')));
              }, child: const Text('Refresh')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              const Text('System settings will be managed here'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings not implemented')));
              }, child: const Text('Open Settings')),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditLogsView extends StatelessWidget {
  const _AuditLogsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              const Text('Audit logs viewer will be here'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () {
                // TODO: link to AuditLogScreen
                Navigator.of(context).pushNamed('/admin'); // placeholder
              }, child: const Text('Open Audit Logs')),
            ],
          ),
        ),
      ),
    );
  }
}
