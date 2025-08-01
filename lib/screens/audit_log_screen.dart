import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/audit_log.dart';
import '../services/audit_service.dart';
import '../services/api_service.dart';
import '../utils/date_util.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _auditService = AuditService();
  List<AuditLog> _logs = [];
  bool _isLoading = false;
  String? _selectedType;
  List<String> _availableTypes = [];
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadTypes(),
        _fetchLogs(),
      ]);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTypes() async {
    final types = await _auditService.getLogTypes();
    setState(() => _availableTypes = types);
  }

  Future<void> _fetchLogs() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final logs = await _auditService.getAuditLogs(
        plantId: ApiService.defaultPlantId,
        type: _selectedType,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );

      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching logs: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _logs = [];
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load audit logs. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _fetchLogs,
            ),
          ),
        );
      }
    }
  }

  Future<void> _showDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _fetchLogs();
    }
  }

  Future<void> _exportLogs() async {
    try {
      setState(() => _isLoading = true);

      final queryParams = {
        'plantId': ApiService.defaultPlantId,
        if (_selectedType != null) 'type': _selectedType,
        if (_dateRange != null) ...{
          'start': _dateRange!.start.toIso8601String(),
          'end': _dateRange!.end.toIso8601String(),
        },
        'format': 'csv'
      };

      final url = Uri.parse('${ApiService.baseUrl}/audit-logs/export')
          .replace(queryParameters: queryParams);

      // Open URL in browser for download
      await launchUrl(url, mode: LaunchMode.externalApplication);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audit log export started')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export logs: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _isLoading ? null : _exportLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildLogList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Event Type',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedType,
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Types')),
                      ..._availableTypes.map((type) => DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Text(AuditLog(
                                  id: '',
                                  plantId: '',
                                  type: type,
                                  action: '',
                                  status: '',
                                  timestamp: DateTime.now(),
                                ).getIcon()),
                                const SizedBox(width: 8),
                                Text(type.toUpperCase()),
                              ],
                            ),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedType = value);
                      _fetchLogs();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Date'),
                    onPressed: _showDatePicker,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            if (_dateRange != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Date Range: ${DateUtil.formatDateRange(_dateRange!.start, _dateRange!.end)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogList() {
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No audit logs found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: _fetchLogs,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLogs,
      child: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return _buildLogCard(log, context);
        },
      ),
    );
  }

  Widget _buildLogCard(AuditLog log, BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: log.getColor().withOpacity(0.1),
          child: Text(
            log.getIcon(),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          '${log.getDisplayTitle()}: ${log.action.replaceAll('_', ' ').toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateUtil.formatDateTime(log.timestamp),
              style: TextStyle(fontSize: 12, color: theme.hintColor),
            ),
            if (log.details != null)
              Text(
                log.details!,
                style: TextStyle(fontSize: 11, color: theme.hintColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: log.getColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            log.status.toUpperCase(),
            style: TextStyle(
              color: log.getColor(),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.details != null) ...[
                  Text('Details:', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(log.details!),
                  const SizedBox(height: 8),
                ],
                if (log.sensorData != null) ...[
                  Text('Sensor Data:', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  _buildSensorDataGrid(log.sensorData!),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Type: ${log.getDisplayTitle()}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'Action: ${log.action.replaceAll('_', ' ').toUpperCase()}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'Status: ${log.status.toUpperCase()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: log.getColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Time: ${DateUtil.formatDateTimeDetailed(log.timestamp)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDataGrid(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (data['moisture'] != null)
              _buildSensorDataItem(
                Icons.water_drop,
                'Moisture',
                '${data['moisture']}%',
                Colors.blue,
              ),
            if (data['temperature'] != null)
              _buildSensorDataItem(
                Icons.thermostat,
                'Temperature',
                '${data['temperature']}°C',
                Colors.orange,
              ),
            if (data['humidity'] != null)
              _buildSensorDataItem(
                Icons.water,
                'Humidity',
                '${data['humidity']}%',
                Colors.green,
              ),
            if (data['moistureStatus'] != null)
              _buildSensorDataItem(
                Icons.info_outline,
                'Status',
                data['moistureStatus'].toString(),
                Colors.purple,
              ),
            if (data['isConnected'] != null)
              _buildSensorDataItem(
                Icons.wifi,
                'Connection',
                data['isConnected'] ? 'ONLINE' : 'OFFLINE',
                data['isConnected'] ? Colors.green : Colors.red,
              ),
          ],
        ),
        if (data['waterState'] != null || data['fertilizerState'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (data['waterState'] != null)
                  _buildSensorDataItem(
                    Icons.opacity,
                    'Water Pump',
                    data['waterState'] ? 'ON' : 'OFF',
                    Colors.blue,
                  ),
                if (data['fertilizerState'] != null)
                  _buildSensorDataItem(
                    Icons.local_florist,
                    'Fertilizer',
                    data['fertilizerState'] ? 'ON' : 'OFF',
                    Colors.green,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSensorDataItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text('$label: $value', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

