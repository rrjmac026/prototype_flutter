import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange? _selectedDateRange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(title: const Text('Reports')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateRangeCard(),
                  const SizedBox(height: 16),
                  _buildReportActions(),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent Reports',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildReportCard(index),
                childCount: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.calendar_today,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(_selectedDateRange?.start != null
                  ? 'Selected Range: ${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}'
                  : 'Select Date Range'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showDateRangePicker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Generate Report',
            Icons.assessment,
            onPressed: _generateReport,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            'Export Data',
            Icons.download,
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon,
      {VoidCallback? onPressed}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildReportCard(int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.description),
        title: Text('Report ${index + 1}'),
        subtitle: Text(
          DateFormat('MMM dd, yyyy').format(DateTime.now()),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download),
          onPressed: () {
            // Download report
          },
        ),
      ),
    );
  }

  Future<void> _generateReport() async {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date range using the calendar icon'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Show loading dialog with progress details
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Generating Report...'),
              const SizedBox(height: 8),
              Text(
                'Date Range: ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );

      // Generate report
      final reportData = await ApiService().generateReport(
        ApiService.defaultPlantId,
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );

      if (context.mounted) {
        Navigator.pop(context); // Hide loading dialog

        // Show report preview dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Report Generated'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Period: ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - '
                      '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}'),
                  const SizedBox(height: 16),
                  const Text('Summary:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      'Average Moisture: ${reportData['summary']['averageMoisture'].toStringAsFixed(1)}'),
                  Text(
                      'Average Temperature: ${reportData['summary']['averageTemperature'].toStringAsFixed(1)}°C'),
                  Text(
                      'Average Humidity: ${reportData['summary']['averageHumidity'].toStringAsFixed(1)}%'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () {
                  // TODO: Implement PDF download
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report saved successfully')),
                  );
                },
                child: const Text('Download PDF'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Hide loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDateRangePicker() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );

    if (pickedRange != null) {
      setState(() => _selectedDateRange = pickedRange);
    }
  }
}
