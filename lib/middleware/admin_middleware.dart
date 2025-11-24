import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype/providers/auth_provider.dart';
import 'package:prototype/screens/admin_screen.dart';

class AdminMiddleware {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    if (settings.name == '/admin') {
      return MaterialPageRoute(
        builder: (context) => _AdminGuard(
          child: const AdminScreen(),
        ),
      );
    }
    throw Exception('Unknown route: ${settings.name}');
  }
}

class _AdminGuard extends StatelessWidget {
  final Widget child;

  const _AdminGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userRole = authProvider.user?['role'] ?? 'user';

        if (!authProvider.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/login');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userRole != 'admin') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Admin access required')),
            );
            Navigator.of(context).pop();
          });
          return const Scaffold(
            body: Center(child: Text('Unauthorized')),
          );
        }

        return child;
      },
    );
  }
}
