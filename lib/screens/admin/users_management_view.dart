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
  String _searchQuery = '';
  late Future<void> _loadUsersFuture;

  @override
  void initState() {
    super.initState();
    _loadUsersFuture = _loadUsers();
  }

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

  List<dynamic> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _users;
    }
    return _users
        .where((user) {
          final email = (user['email'] ?? user['mail'] ?? '').toString().toLowerCase();
          final username = (user['username'] ?? user['name'] ?? '').toString().toLowerCase();
          final query = _searchQuery.toLowerCase();
          return email.contains(query) || username.contains(query);
        })
        .toList();
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'user':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.teal.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Management',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage system users and permissions',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _loading ? null : _loadUsers,
                      icon: _loading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Refresh users',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search Bar
                TextField(
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          // Users List Section
          Expanded(
            child: _loading && _users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _users.isEmpty ? 'No users found' : 'No results match your search',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _users.isEmpty ? 'Users will appear here' : 'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          if (_users.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final email = user['email'] ?? user['mail'] ?? '—';
        final username = user['username'] ?? user['name'] ?? '—';
        final role = (user['role'] ?? 'user').toString();
        final roleColor = _getRoleColor(role);
        final initials = username.isNotEmpty ? username[0].toUpperCase() : '?';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: roleColor.withOpacity(0.2),
              child: Text(
                initials,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
              ),
            ),
            title: Text(
              username,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              email,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roleColor.withOpacity(0.3)),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User actions not implemented')),
              );
            },
          ),
        );
      },
    );
  }
}
