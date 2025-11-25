import 'package:flutter/material.dart';
import 'package:prototype/services/audit_service.dart';
import 'package:prototype/services/api_service.dart';
import 'package:prototype/models/audit_log.dart';
import 'package:prototype/utils/date_util.dart';
import 'package:prototype/providers/schedule_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with TickerProviderStateMixin {
  final _auditService = AuditService();
  late Stream<List<AuditLog>> _recentActivityStream;
  int _totalUsers = 0;
  Timer? _statsTimer;

  late AnimationController _headerController;
  late AnimationController _statsController;
  late Animation<double> _headerOpacity;
  late Animation<Offset> _headerSlide;
  late Animation<double> _statsScale;

  @override
  void initState() {
    super.initState();

    // Header animations
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _headerOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );

    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
        );

    // Stats animations
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _statsScale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _statsController,
        curve: const Interval(0.2, 1, curve: Curves.elasticOut),
      ),
    );

    // Start animations sequentially
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _statsController.forward();
    });

    _recentActivityStream = Stream.periodic(
      const Duration(seconds: 5),
      (_) => DateTime.now(),
    ).asyncMap((_) => _auditService.getAuditLogs(
          plantId: ApiService.defaultPlantId,
          limit: 3,
        ));

    // Fetch users count periodically
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      _fetchUsersCount();
    });

    // Load schedules on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ScheduleProvider>(context, listen: false)
            .fetchSchedules(ApiService.defaultPlantId);
      }
    });

    // Fetch initial users count
    _fetchUsersCount();
  }

  Future<void> _fetchUsersCount() async {
    try {
      final response = await ApiService.get('/auth/users');
      if (response.statusCode == 200) {
        final body = response.body;
        if (body.isNotEmpty) {
          final parsed = Uri.parse('http://test').queryParameters;
          if (mounted) {
            setState(() {
              _totalUsers = 5; // Placeholder - update based on your API response
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching users count: $e');
    }
  }

  Color _getActivityColor(String type) {
    switch (type.toLowerCase()) {
      case 'auth':
        return Colors.purple;
      case 'sensor':
        return Colors.blue;
      case 'schedule':
        return Colors.orange;
      case 'report':
        return Colors.green;
      case 'user':
        return Colors.indigo;
      case 'system':
        return Colors.teal;
      case 'maintenance':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'auth':
        return Icons.security;
      case 'sensor':
        return Icons.sensors;
      case 'schedule':
        return Icons.schedule;
      case 'report':
        return Icons.assessment;
      case 'user':
        return Icons.person;
      case 'system':
        return Icons.settings;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SlideTransition(
            position: _headerSlide,
            child: FadeTransition(
              opacity: _headerOpacity,
              child: _buildHeaderSection(context),
            ),
          ),
          const SizedBox(height: 24),
          ScaleTransition(
            scale: _statsScale,
            child: _buildStatsGrid(context),
          ),
          const SizedBox(height: 24),
          _buildRecentActivitySection(context),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.teal.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.green.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.dashboard_customize,
                  color: Colors.green.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Dashboard',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'System overview and recent activities',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Last updated: just now',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, scheduleProvider, _) {
        final stats = [
          {
            'title': 'Active Users',
            'value': _totalUsers.toString(),
            'icon': Icons.people,
            'color': Colors.blue,
            'subtitle': 'Registered'
          },
        ];

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: List.generate(stats.length, (index) {
            return _buildStatCard(context, stats[index]);
          }),
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, Map<String, dynamic> stat) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              (stat['color'] as Color).withOpacity(0.1),
              (stat['color'] as Color).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon positioned at top right
            Align(
              alignment: Alignment.topRight,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: (stat['color'] as Color).withOpacity(0.2),
                child: Icon(
                  stat['icon'] as IconData,
                  color: stat['color'] as Color,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title and value
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat['title'] as String,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  stat['value'] as String,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: stat['color'] as Color,
                    fontSize: 22,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Subtitle at bottom
            Text(
              stat['subtitle'] as String,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade500,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<AuditLog>>(
            stream: _recentActivityStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }

              if (snapshot.hasError) {
                debugPrint('Stream error: ${snapshot.error}');
                return _buildErrorState();
              }

              final logs = snapshot.data ?? [];

              if (logs.isEmpty) {
                return _buildEmptyState();
              }

              return Column(
                children: List.generate(
                  logs.take(3).length,
                  (index) => _buildAnimatedActivityCard(
                    context,
                    logs.take(3).toList()[index],
                    index,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedActivityCard(
      BuildContext context, AuditLog log, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 150)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: _buildActivityCard(context, log),
    );
  }

  Widget _buildLoadingState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.green.shade600),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading activities...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                'Failed to load activities',
                style: TextStyle(color: Colors.red.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No recent activities',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Activity logs will appear here',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, AuditLog log) {
    final color = _getActivityColor(log.type);
    final icon = _getActivityIcon(log.type);
    final timeAgo = DateUtil.getTimeAgo(log.timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, color: color, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.getDisplayTitle(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.getActionDisplay(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (log.getSystemDetails() != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.getSystemDetails()!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: log.status.toLowerCase() == 'success'
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: log.status.toLowerCase() == 'success'
                          ? Colors.green.shade200
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Text(
                    log.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: log.status.toLowerCase() == 'success'
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _headerController.dispose();
    _statsController.dispose();
    _statsTimer?.cancel();
    super.dispose();
  }
}
