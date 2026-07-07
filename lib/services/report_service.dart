import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/task_category.dart';
import '../models/task.dart';
import '../models/task_period.dart';

class ReportService {
  Future<Directory> _ensureDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'reports'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String> generatePdf({
    required List<Task> tasks,
    required List<TaskCategory> categories,
    required List<TaskPeriod> periods,
    required DateTime from,
    required DateTime to,
    Map<String, List<TaskCategory>>? taskCats,
  }) async {
    final periodsByTask = <String, List<TaskPeriod>>{};
    for (final p in periods) {
      periodsByTask.putIfAbsent(p.taskId, () => []).add(p);
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('JobTrackr — Accomplishment Report',
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${_formatDate(from)}  →  ${_formatDate(to)}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.Divider(),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _summaryCol('Tasks', '${tasks.length}'),
                _summaryCol('Periods', '${periods.length}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          ...tasks.expand((t) {
            final tPeriods = periodsByTask[t.id] ?? [];
            final cats = taskCats?[t.id] ?? [];
            final catNames = cats.map((c) => c.name).join(', ');
            final children = <pw.Widget>[
              pw.SizedBox(height: 6),
              pw.Text('• ${t.title}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.SizedBox(height: 4),
              ...tPeriods.map((tp) {
                final line = tp.isSingleDay
                    ? _formatDate(tp.startDate)
                    : '${_formatDate(tp.startDate)} — ${_formatDate(tp.endDate!)}';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 14),
                  child: pw.Text('  - $line',
                      style: const pw.TextStyle(fontSize: 11)),
                );
              }),
            ];
            if (catNames.isNotEmpty) {
              children.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 14, top: 4),
                child: pw.Text(catNames,
                    style: pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700)),
              ));
            }
            if (t.description != null && t.description!.isNotEmpty) {
              children.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 14, top: 1),
                child: pw.Text(t.description!,
                    style: const pw.TextStyle(fontSize: 10)),
              ));
            }
            children.add(pw.SizedBox(height: 8));
            return children;
          }),
        ],
      ),
    );

    final dir = await _ensureDir();
    final file = File(p.join(dir.path,
        'jobtrackr_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf'));
    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  static pw.Widget _summaryCol(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      );

  Future<String> generateCsv({
    required List<Task> tasks,
    required List<TaskPeriod> periods,
    required DateTime from,
    required DateTime to,
    Map<String, List<TaskCategory>>? taskCats,
  }) async {
    final rows = <List<dynamic>>[
      ['Task', 'Date(s)', 'Categories', 'Description'],
    ];
    for (final t in tasks) {
      final tPeriods = periods.where((p) => p.taskId == t.id).toList();
      final cats = taskCats?[t.id] ?? [];
      final catNames = cats.map((c) => c.name).join('; ');
      for (final tp in tPeriods) {
        rows.add([
          t.title,
          tp.isSingleDay
              ? _formatDate(tp.startDate)
              : '${_formatDate(tp.startDate)} — ${_formatDate(tp.endDate!)}',
          catNames,
          t.description ?? '',
        ]);
      }
    }
    final csv = ListToCsvConverter().convert(rows);
    final dir = await _ensureDir();
    final file = File(p.join(dir.path,
        'jobtrackr_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv'));
    await file.writeAsString(csv);
    return file.path;
  }

  Future<void> share(String filePath) async {
    if (!File(filePath).existsSync()) return;
    await Share.shareXFiles([XFile(filePath)], text: 'JobTrackr report');
  }

  String _formatDate(DateTime d) => DateFormat('MMMM d, yyyy').format(d);
}

// Simple CSV converter (avoids dependency on csv package for ListToCsvConverter)
class ListToCsvConverter {
  String convert(List<List<dynamic>> rows) {
    final buf = StringBuffer();
    for (final row in rows) {
      buf.writeln(row.map((cell) {
        final s = '$cell';
        if (s.contains(',') || s.contains('"') || s.contains('\n')) {
          return '"${s.replaceAll('"', '""')}"';
        }
        return s;
      }).join(','));
    }
    return buf.toString();
  }
}