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
        const SnackBar(content: Text('Please select a date range first')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final reportData = await ApiService().generateReport(
        ApiService.defaultPlantId,
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Hide loading dialog

      // Save and open PDF
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/plant_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(reportData);

      if (!context.mounted) return;

      // Show success dialog with options
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Report Generated'),
          content: const Text('Report has been generated successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Hide loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
