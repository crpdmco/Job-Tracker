import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/task_category.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../utils/time_utils.dart';

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
    required List<TimeEntry> entries,
    required DateTime from,
    required DateTime to,
    Map<String, List<TaskCategory>>? taskCats,
  }) async {
    final taskMap = {for (final t in tasks) t.id: t};

    // Per-task aggregation
    final Map<String, Duration> totals = {};
    final Map<String, List<TimeEntry>> byTask = {};
    for (final e in entries) {
      totals[e.taskId] = (totals[e.taskId] ?? Duration.zero) + e.duration;
      byTask.putIfAbsent(e.taskId, () => []).add(e);
    }

    final grandTotal = totals.values.fold(Duration.zero, (a, b) => a + b);

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
                  '${TimeUtils.formatDate(from)}  →  ${TimeUtils.formatDate(to)}',
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
                _summaryCol('Tasks', '${byTask.length}'),
                _summaryCol('Sessions', '${entries.length}'),
                _summaryCol('Total time', TimeUtils.formatHoursCompact(grandTotal)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, text: 'Tasks Summary'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            headers: const ['Task', 'Category', 'Time', 'Sessions'],
            data: byTask.keys.map((id) {
              final t = taskMap[id]!;
              final cats = taskCats?[id] ?? [];
              final catNames =
                  cats.map((c) => c.name).join(', ');
              return [
                t.title,
                catNames.isEmpty ? '—' : catNames,
                TimeUtils.formatHoursCompact(totals[id]!),
                '${byTask[id]!.length}',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, text: 'Detailed Sessions'),
          ...byTask.entries.expand((entry) {
            final t = taskMap[entry.key]!;
            return [
              pw.SizedBox(height: 4),
              pw.Text('• ${t.title}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.SizedBox(height: 2),
              pw.TableHelper.fromTextArray(
                cellPadding:
                    const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                headers: const ['Date', 'Start', 'End', 'Duration', 'Note'],
                data: entry.value.map((e) {
                  return [
                    TimeUtils.formatDate(e.startTime),
                    TimeUtils.formatTime(e.startTime),
                    e.endTime != null ? TimeUtils.formatTime(e.endTime!) : '—',
                    TimeUtils.formatHoursCompact(e.duration),
                    e.note ?? '',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 10),
            ];
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
    required List<TimeEntry> entries,
    required DateTime from,
    required DateTime to,
  }) async {
    final taskMap = {for (final t in tasks) t.id: t};
    final rows = <List<dynamic>>[
      ['Task', 'Start', 'End', 'Duration (h)', 'Note'],
      ...entries.map((e) {
        final t = taskMap[e.taskId];
        return [
          t?.title ?? 'Unknown',
          e.startTime.toIso8601String(),
          e.endTime?.toIso8601String() ?? '',
          (e.duration.inSeconds / 3600).toStringAsFixed(3),
          e.note ?? '',
        ];
      }),
    ];
    final csv = const ListToCsvConverter().convert(rows);
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
}
