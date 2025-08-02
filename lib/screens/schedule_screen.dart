import 'package:flutter/material.dart';
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
        title: const Text('Watering Schedule'),
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

          if (scheduleProvider.error != null &&
              scheduleProvider.schedules.isEmpty) {
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
                  const SizedBox(height: 24),
                  const Text(
                    'If the problem persists, please check your internet connection or try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Show a banner if there's an error but we still have schedules to display
          if (scheduleProvider.error != null &&
              scheduleProvider.schedules.isNotEmpty) {
            return Column(
              children: [
                Container(
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'There was an issue refreshing schedules. Showing last known data.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => scheduleProvider.refreshSchedules(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildScheduleList(scheduleProvider),
                ),
              ],
            );
          }

          if (scheduleProvider.schedules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No schedules found',
                    style: TextStyle(fontSize: 18),
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
            onPressed: () => _showAddScheduleDialog(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Add New Schedule'),
          ),
        ),
      ],
    );
  }

  void _showAddScheduleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ScheduleDialog(
        onSave: (schedule) async {
          try {
            final provider =
                Provider.of<ScheduleProvider>(context, listen: false);
            await provider.createSchedule(schedule);
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Schedule created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create schedule: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _showEditScheduleDialog(BuildContext context, Schedule schedule) {
    showDialog(
      context: context,
      builder: (context) => ScheduleDialog(
        schedule: schedule,
        onSave: (updatedSchedule) {
          Provider.of<ScheduleProvider>(context, listen: false)
              .updateSchedule(schedule.id!, {
            'type': updatedSchedule.type,
            'time': updatedSchedule.time,
            'days': updatedSchedule.days,
            'duration': updatedSchedule.duration,
            'enabled': updatedSchedule.enabled,
            'label': updatedSchedule.label,
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _confirmDeleteSchedule(BuildContext context, Schedule schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text(
            'Are you sure you want to delete this ${schedule.type} schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ScheduleProvider>(context, listen: false)
                  .deleteSchedule(schedule.id!);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
                  onChanged: onToggle,
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
            Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Days: ${schedule.days.join(', ')}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
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
      title: Text(widget.schedule == null ? 'Add Schedule' : 'Edit Schedule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Text('$_duration minutes'),
            const SizedBox(height: 16),

            // Label field
            const Text('Label (optional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                hintText: 'e.g., Morning, Evening',
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
                const SnackBar(
                  content: Text('Please select at least one day'),
                ),
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
            );

            widget.onSave(schedule);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
