import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:prototype/services/api_service.dart';

class UsersManagementView extends StatefulWidget {
  const UsersManagementView({super.key});

  @override
  State<UsersManagementView> createState() => _UsersManagementViewState();
}

class _UsersManagementViewState extends State<UsersManagementView> {
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
