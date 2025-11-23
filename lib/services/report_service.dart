import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:prototype/models/plant_data.dart';
import '../services/audit_service.dart';

class ReportService {
  final AuditService _auditService = AuditService();

  Future<File> generateReport(
      List<PlantData> data, DateTimeRange dateRange) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Plant Monitoring Report',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Date Range: ${dateRange.start} - ${dateRange.end}'),
              pw.SizedBox(height: 20),
              _buildDataTable(data),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/plant_report.pdf');
    await file.writeAsBytes(await pdf.save());

    try {
      // Log the report generation
      await _auditService.logReportActivity(
        'generated',
        {
          'startDate': dateRange.start.toIso8601String(),
          'endDate': dateRange.end.toIso8601String(),
          'dataCount': data.length,
        },
      );
    } catch (e) {
      // Handle any errors from the audit logging
      print('Failed to log report generation: $e');
    }

    return file;
  }

  pw.Widget _buildDataTable(List<PlantData> data) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            pw.Text('Date'),
            pw.Text('Moisture'),
            pw.Text('Temperature'),
            pw.Text('Humidity'),
          ],
        ),
        ...data.map((item) => pw.TableRow(
              children: [
                pw.Text(item.timestamp.toString()),
                pw.Text('${item.soilMoisture}%'),
                pw.Text('${item.temperature}°C'),
                pw.Text('${item.humidity}%'),
              ],
            )),
      ],
    );
  }
}
