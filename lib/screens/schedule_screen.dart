import 'package:flutter/material.dart';
import 'dart:convert'; // Add this import
import 'package:provider/provider.dart';
import 'package:prototype/models/schedule.dart';
import 'package:prototype/providers/schedule_provider.dart';
import 'package:prototype/services/api_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch schedules when the screen is first loaded
    _loadSchedules();
  }

  void _loadSchedules() {
    // Add a small delay to ensure the widget is fully mounted
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Provider.of<ScheduleProvider>(context, listen: false)
            .fetchSchedules(ApiService.defaultPlantId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduling Page'),
        actions: [
          Consumer<ScheduleProvider>(
            builder: (context, provider, _) => IconButton(
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              onPressed: provider.isLoading
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Refreshing schedules...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      Provider.of<ScheduleProvider>(context, listen: false)
                          .refreshSchedules();
                    },
            ),
          ),
        ],
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, child) {
          if (scheduleProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (scheduleProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${scheduleProvider.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    onPressed: () => scheduleProvider.refreshSchedules(),
                  ),
                ],
              ),
            );
          }

          if (scheduleProvider.schedules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No schedules found',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the button below to create a new schedule',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showAddScheduleDialog(context),
                    child: const Text('Add Schedule'),
                  ),
                ],
              ),
            );
          }

          return _buildScheduleList(scheduleProvider);
        },
      ),
    );
  }

  Widget _buildScheduleList(ScheduleProvider scheduleProvider) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => scheduleProvider.refreshSchedules(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: scheduleProvider.schedules.length,
              itemBuilder: (context, index) {
                final schedule = scheduleProvider.schedules[index];
                return ScheduleCard(
                  schedule: schedule,
                  onEdit: () => _showEditScheduleDialog(context, schedule),
                  onDelete: () => _confirmDeleteSchedule(context, schedule),
                  onToggle: (enabled) {
                    scheduleProvider.toggleScheduleEnabled(
                        schedule.id!, enabled);
                  },
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () =>
                _showAddScheduleDialog(context), // Pass the current context
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Add New Schedule'),
          ),
        ),
      ],
    );
  }

  void _showAddScheduleDialog(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Schedule Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.water_drop, color: Colors.blue),
              title: const Text('Watering Schedule'),
              onTap: () {
                Navigator.pop(dialogContext);
                _showWateringScheduleDialog(
                    parentContext); // Pass parentContext
              },
            ),
            ListTile(
              leading: const Icon(Icons.grass, color: Colors.green),
              title: const Text('Fertilizing Schedule'),
              onTap: () {
                Navigator.pop(dialogContext);
                _showFertilizingScheduleDialog(
                    parentContext); // Pass parentContext
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showWateringScheduleDialog(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => WateringScheduleDialog(
        onSave: (schedule) async {
          // Close the dialog first
          Navigator.of(dialogContext).pop();

          // Use parentContext instead of context from the async callback
          await _handleScheduleOperation(
            parentContext,
            () async {
              final provider =
                  Provider.of<ScheduleProvider>(parentContext, listen: false);
              return await provider.createSchedule(schedule);
            },
            'Watering schedule created successfully',
            'Failed to create watering schedule',
            onRetry: () => _showWateringScheduleDialog(parentContext),
          );
        },
      ),
    );
  }

  void _showFertilizingScheduleDialog(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => FertilizingScheduleDialog(
        onSave: (schedule) async {
          // Close the dialog first
          Navigator.of(dialogContext).pop();

          // Use parentContext (which is the ScheduleScreen context) instead of dialogContext
          await _handleScheduleOperation(
            parentContext, // Use parentContext here, not dialogContext
            () async {
              final provider =
                  Provider.of<ScheduleProvider>(parentContext, listen: false);

              // Create proper schedule data for fertilizing
              final scheduleData = {
                'plantId': schedule.plantId,
                'type': 'fertilizing',
                'time': schedule.time,
                'days': [], // Empty for fertilizing schedules
                'calendarDays': schedule.calendarDays, // Changed semicolon to comma
                'duration': schedule.duration,
                'enabled': schedule.enabled,
                'label': schedule.label,
                'settings': schedule.settings?.toJson()
              };

              debugPrint(
                  '🔍 Creating fertilizing schedule with data: ${json.encode(scheduleData)}');

              return await provider
                  .createSchedule(Schedule.fromJson(scheduleData));
            },
            'Fertilizing schedule created successfully',
            'Failed to create fertilizing schedule',
            onRetry: () => _showFertilizingScheduleDialog(
                parentContext), // Use parentContext for retry too
          );
        },
      ),
    );
  }

  void _showEditScheduleDialog(BuildContext context, Schedule schedule) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        if (schedule.type == 'watering') {
          return WateringScheduleDialog(
            schedule: schedule,
            onSave: (updatedSchedule) async {
              Navigator.of(context).pop();
              await _handleScheduleOperation(
                context,
                () async {
                  final provider =
                      Provider.of<ScheduleProvider>(context, listen: false);
                  return await provider.updateSchedule(schedule.id!, {
                    'type': updatedSchedule.type,
                    'time': updatedSchedule.time,
                    'days': updatedSchedule.days,
                    'duration': updatedSchedule.duration,
                    'enabled': updatedSchedule.enabled,
                    'label': updatedSchedule.label,
                    'settings': updatedSchedule.settings?.toJson(),
                  });
                },
                'Schedule updated successfully',
                'Failed to update schedule',
                onRetry: () => _showEditScheduleDialog(context, schedule),
              );
            },
          );
        } else {
          return FertilizingScheduleDialog(
            schedule: schedule,
            onSave: (updatedSchedule) async {
              Navigator.of(context).pop();
              await _handleScheduleOperation(
                context,
                () async {
                  final provider =
                      Provider.of<ScheduleProvider>(context, listen: false);
                  return await provider.updateSchedule(schedule.id!, {
                    'type': updatedSchedule.type,
                    'time': updatedSchedule.time,
                    'calendarDays': updatedSchedule.calendarDays,
                    'duration': updatedSchedule.duration,
                    'enabled': updatedSchedule.enabled,
                    'label': updatedSchedule.label,
                    'settings': updatedSchedule.settings?.toJson(),
                  });
                },
                'Schedule updated successfully',
                'Failed to update schedule',
                onRetry: () => _showEditScheduleDialog(context, schedule),
              );
            },
          );
        }
      },
    );
  }

  void _confirmDeleteSchedule(BuildContext context, Schedule schedule) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text(
          'Are you sure you want to delete this ${schedule.type} schedule?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(); // Close confirmation dialog
              await _handleScheduleOperation(
                context,
                () async {
                  final provider =
                      Provider.of<ScheduleProvider>(context, listen: false);
                  return await provider.deleteSchedule(schedule.id!);
                },
                'Schedule deleted successfully',
                'Failed to delete schedule',
                onRetry: () => _confirmDeleteSchedule(context, schedule),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Centralized method to handle schedule operations with consistent error handling
  Future<void> _handleScheduleOperation(
    BuildContext context,
    Future<bool> Function() operation,
    String successMessage,
    String failureMessage, {
    VoidCallback? onRetry,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Perform the operation
      final result = await operation();

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Wait a bit and refresh the list to verify the operation
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await Provider.of<ScheduleProvider>(context, listen: false)
            .refreshSchedules();
      }

      // Show appropriate message based on result
      if (mounted) {
        if (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Operation returned false - show error with retry option
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failureMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: onRetry != null
                  ? SnackBarAction(
                      label: 'Retry',
                      textColor: Colors.white,
                      onPressed: onRetry,
                    )
                  : null,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Handle exceptions
      if (mounted) {
        final errorMessage = _getUserFriendlyErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: onRetry != null
                ? SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: onRetry,
                  )
                : null,
          ),
        );
      }
    }
  }

  /// Convert technical errors to user-friendly messages
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection error. Please check your internet connection.';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorString.contains('unauthorized') ||
        errorString.contains('401')) {
      return 'Authentication error. Please log in again.';
    } else if (errorString.contains('forbidden') ||
        errorString.contains('403')) {
      return 'You don\'t have permission to perform this action.';
    } else if (errorString.contains('not found') ||
        errorString.contains('404')) {
      return 'Resource not found. It may have been deleted.';
    } else if (errorString.contains('server') || errorString.contains('500')) {
      return 'Server error. Please try again later.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}

class ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggle;

  const ScheduleCard({
    Key? key,
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  }) : super(key: key);

  Widget _buildSettingsInfo() {
    if (schedule.settings == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        if (schedule.type == 'watering')
          ListTile(
            leading: const Icon(Icons.water_drop),
            title: Text(
                'Moisture Threshold: ${schedule.settings!.moistureThreshold.round()}%'),
            subtitle:
                Text('Mode: ${schedule.settings!.moistureMode.toUpperCase()}'),
            dense: true,
          ),
        if (schedule.type == 'fertilizing')
          ListTile(
            leading: const Icon(Icons.grass),
            title:
                Text('Amount: ${schedule.settings!.fertilizerAmount.round()}%'),
            subtitle: Text(
                'Mode: ${schedule.settings!.fertilizerMode.toUpperCase()}'),
            dense: true,
          ),
      ],
    );
  }

  Widget _buildDaysInfo() {
    if (schedule.type == 'fertilizing' && schedule.calendarDays != null) {
      return Row(
        children: [
          const Icon(Icons.calendar_today),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Monthly on day${schedule.calendarDays!.length > 1 ? "s" : ""}: '
              '${schedule.calendarDays!.join(", ")}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.calendar_today),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Days: ${schedule.days.join(", ")}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = schedule.type == 'watering' ? Icons.water_drop : Icons.grass;
    final color = schedule.type == 'watering' ? Colors.blue : Colors.green;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.type == 'watering' ? 'Watering' : 'Fertilizing',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (schedule.label != null && schedule.label!.isNotEmpty)
                      Text(
                        schedule.label!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Switch(
                  value: schedule.enabled,
                  onChanged: (newValue) async {
                    try {
                      await onToggle(newValue); // Remove success check since onToggle doesn't return anything
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  activeColor: color,
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.access_time),
                const SizedBox(width: 8),
                Text(
                  'Time: ${schedule.time}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDaysInfo(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer),
                const SizedBox(width: 8),
                Text(
                  'Duration: ${schedule.duration} minutes',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingsInfo(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ScheduleDialog extends StatefulWidget {
  final Schedule? schedule;
  final Function(Schedule) onSave;

  const ScheduleDialog({
    Key? key,
    this.schedule,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  late String _type;
  late TimeOfDay _time;
  late List<String> _days;
  late int _duration;
  late bool _enabled;
  late TextEditingController _labelController;
  late ScheduleSettings _settings;

  final List<String> _availableDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> _suggestedLabels = [
    'Morning',
    'Afternoon',
    'Evening',
    'Night',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.schedule?.type ?? 'watering';
    _time = widget.schedule != null
        ? _parseTimeString(widget.schedule!.time)
        : TimeOfDay.now();
    _days = widget.schedule?.days ?? ['Monday'];
    _duration = widget.schedule?.duration ?? 5;
    _enabled = widget.schedule?.enabled ?? true;
    _labelController =
        TextEditingController(text: widget.schedule?.label ?? '');
    _settings = widget.schedule?.settings ?? ScheduleSettings();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text('Advanced Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_type == 'watering') ...[
          const Text('Moisture Threshold'),
          Slider(
            value: _settings.moistureThreshold,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_settings.moistureThreshold.round()}%',
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(moistureThreshold: value);
              });
            },
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'auto', label: Text('Auto')),
              ButtonSegment(value: 'scheduled', label: Text('Scheduled')),
              ButtonSegment(value: 'manual', label: Text('Manual')),
            ],
            selected: {_settings.moistureMode},
            onSelectionChanged: (Set<String> selection) {
              setState(() {
                _settings = _settings.copyWith(moistureMode: selection.first);
              });
            },
          ),
        ],
        if (_type == 'fertilizing') ...[
          const Text('Fertilizer Amount'),
          Slider(
            value: _settings.fertilizerAmount,
            min: 0,
            max: 100,
            divisions: 10,
            label: '${_settings.fertilizerAmount.round()}%',
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(fertilizerAmount: value);
              });
            },
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'scheduled', label: Text('Scheduled')),
              ButtonSegment(value: 'manual', label: Text('Manual')),
            ],
            selected: {_settings.fertilizerMode},
            onSelectionChanged: (Set<String> selection) {
              setState(() {
                _settings = _settings.copyWith(fertilizerMode: selection.first);
              });
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.schedule == null ? 'Add Schedule' : 'Edit Schedule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Fix: MainSize -> MainAxisSize
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type selection
            const Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'watering',
                  label: Text('Watering'),
                  icon: Icon(Icons.water_drop),
                ),
                ButtonSegment(
                  value: 'fertilizing',
                  label: Text('Fertilizing'),
                  icon: Icon(Icons.grass),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _type = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Time selection
            const Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(_formatTimeOfDay(_time)),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null && picked != _time) {
                  setState(() {
                    _time = picked;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Days selection
            const Text('Days', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: _availableDays.map((day) {
                return FilterChip(
                  label: Text(day),
                  selected: _days.contains(day),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _days.add(day);
                      } else {
                        _days.remove(day);
                      }
                    });
                  },
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Duration selection
            const Text('Duration (minutes)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _duration.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: _duration.toString(),
              onChanged: (value) {
                setState(() {
                  _duration = value.round();
                });
              },
            ),
            const SizedBox(height: 16),

            // Label input
            const Text('Label (optional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                hintText: 'Enter a label',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _labelController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Suggested labels
            Wrap(
              spacing: 8,
              children: _suggestedLabels.map((label) {
                return ActionChip(
                  label: Text(label),
                  onPressed: () {
                    setState(() {
                      _labelController.text = label;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Enabled toggle
            Row(
              children: [
                const Text('Enabled',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: _enabled,
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                ),
              ],
            ),
            _buildSettingsSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_days.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select at least one day')),
              );
              return;
            }

            final schedule = Schedule(
              id: widget.schedule?.id,
              plantId: ApiService.defaultPlantId,
              type: _type,
              time: _formatTimeOfDay(_time),
              days: _days,
              duration: _duration,
              enabled: _enabled,
              label: _labelController.text.isNotEmpty
                  ? _labelController.text
                  : null,
              createdAt: widget.schedule?.createdAt,
              updatedAt: DateTime.now(),
              settings: _settings,
            );

            widget.onSave(schedule);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class WateringScheduleDialog extends StatefulWidget {
  final Schedule? schedule;
  final Function(Schedule) onSave;

  const WateringScheduleDialog({
    Key? key,
    this.schedule,
    required this.onSave,
  }) : super(key: key);

  @override
  State<WateringScheduleDialog> createState() => _WateringScheduleDialogState();
}

class _WateringScheduleDialogState extends State<WateringScheduleDialog> {
  late TimeOfDay _time;
  late List<String> _days;
  late int _duration;
  late bool _enabled;
  late TextEditingController _labelController;
  late ScheduleSettings _settings;

  final List<String> _availableDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> _suggestedLabels = [
    'Morning',
    'Afternoon',
    'Evening',
    'Night',
  ];

  @override
  void initState() {
    super.initState();
    _time = widget.schedule != null
        ? _parseTimeString(widget.schedule!.time)
        : TimeOfDay.now();
    _days = widget.schedule?.days ?? ['Monday'];
    _duration = widget.schedule?.duration ?? 5;
    _enabled = widget.schedule?.enabled ?? true;
    _labelController =
        TextEditingController(text: widget.schedule?.label ?? '');
    _settings = widget.schedule?.settings ?? ScheduleSettings();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.schedule == null
          ? 'Add Watering Schedule'
          : 'Edit Watering Schedule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time selection
            const Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(_formatTimeOfDay(_time)),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null && picked != _time) {
                  setState(() {
                    _time = picked;
                  });
                }
              },
            ),

            // Days selection
            const Text('Days', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: _availableDays.map((day) {
                return FilterChip(
                  label: Text(day),
                  selected: _days.contains(day),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _days.add(day);
                      } else {
                        _days.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            // Duration selection
            const Text('Duration (minutes)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _duration.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: _duration.toString(),
              onChanged: (value) {
                setState(() {
                  _duration = value.round();
                });
              },
            ),

            // Label
            const SizedBox(height: 16),
            const Text('Label (optional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                hintText: 'Enter a label',
              ),
            ),

            // Enabled toggle
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Enabled',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: _enabled,
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_days.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select at least one day')),
              );
              return;
            }

            final schedule = Schedule(
              id: widget.schedule?.id,
              plantId: ApiService.defaultPlantId,
              type: 'watering',
              time: _formatTimeOfDay(_time),
              days: _days,
              duration: _duration,
              enabled: _enabled,
              label: _labelController.text.isNotEmpty
                  ? _labelController.text
                  : null,
              settings: _settings,
            );

            widget.onSave(schedule);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class FertilizingScheduleDialog extends StatefulWidget {
  final Schedule? schedule;
  final Function(Schedule) onSave;

  const FertilizingScheduleDialog({
    Key? key,
    this.schedule,
    required this.onSave,
  }) : super(key: key);

  @override
  State<FertilizingScheduleDialog> createState() =>
      _FertilizingScheduleDialogState();
}

class _FertilizingScheduleDialogState extends State<FertilizingScheduleDialog> {
  late TimeOfDay _time;
  late List<int> _calendarDays;
  late int _duration;
  late bool _enabled;
  late TextEditingController _labelController;
  late ScheduleSettings _settings;

  @override
  void initState() {
    super.initState();
    _time = widget.schedule != null
        ? _parseTimeString(widget.schedule!.time)
        : TimeOfDay.now();
    _calendarDays = widget.schedule?.calendarDays ?? [];
    _duration = widget.schedule?.duration ?? 5;
    _enabled = widget.schedule?.enabled ?? true;
    _labelController =
        TextEditingController(text: widget.schedule?.label ?? '');
    _settings = widget.schedule?.settings ?? ScheduleSettings();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildCalendarDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Days of Month',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(31, (index) {
            final day = index + 1;
            return FilterChip(
              label: Text(day.toString()),
              selected: _calendarDays.contains(day),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (_calendarDays.length < 2) {
                      _calendarDays.add(day);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You can only select up to 2 days'),
                        ),
                      );
                    }
                  } else {
                    _calendarDays.remove(day);
                  }
                  _calendarDays.sort();
                });
              },
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.schedule == null
          ? 'Add Fertilizing Schedule'
          : 'Edit Fertilizing Schedule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time selection
            const Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(_formatTimeOfDay(_time)),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null && picked != _time) {
                  setState(() {
                    _time = picked;
                  });
                }
              },
            ),

            // Calendar Days selection
            _buildCalendarDaySelector(),

            // Duration selection
            const Text('Duration (minutes)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _duration.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: _duration.toString(),
              onChanged: (value) {
                setState(() {
                  _duration = value.round();
                });
              },
            ),

            // Label and enabled toggle
            const SizedBox(height: 16),
            const Text('Label (optional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                hintText: 'Enter a label',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Enabled',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: _enabled,
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_calendarDays.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select at least one day'),
                ),
              );
              return;
            }

            final schedule = Schedule(
              id: widget.schedule?.id,
              plantId: ApiService.defaultPlantId,
              type: 'fertilizing',
              time: _formatTimeOfDay(_time),
              days: [], // Empty array for fertilizing schedules
              calendarDays: _calendarDays,
              duration: _duration,
              enabled: _enabled,
              label: _labelController.text.isNotEmpty
                  ? _labelController.text
                  : null,
              settings: _settings,
            );

            widget.onSave(schedule);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

