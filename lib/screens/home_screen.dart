import 'package:flutter/material.dart';
import 'package:prototype/screens/dashboard_screen.dart';
import 'package:prototype/screens/profile_screen.dart';
import 'package:prototype/screens/messages_screen.dart';
import 'package:prototype/screens/schedule_screen.dart';
import 'package:prototype/screens/audit_log_screen.dart'; // Import the AuditLogScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MessagesScreen(),
    const ScheduleScreen(),
    const AuditLogScreen(), // Add this line
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          NavigationDestination(
            // Add this section
            icon: Icon(Icons.history),
            label: 'Audit Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
