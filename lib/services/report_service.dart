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
    String employeeName = '',
    String employeeId = '',
    String employeeTeam = '',
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
                pw.Text('Job Accomplishments',
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                  'From ${_formatMonthYear(from)}  To  ${_formatMonthYear(to)}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 8),
                if (employeeName.isNotEmpty)
                  pw.Text('Name: $employeeName',
                      style: const pw.TextStyle(fontSize: 11)),
                if (employeeId.isNotEmpty)
                  pw.Text('ID: $employeeId',
                      style: const pw.TextStyle(fontSize: 11)),
                if (employeeTeam.isNotEmpty)
                  pw.Text('Team: $employeeTeam',
                      style: const pw.TextStyle(fontSize: 11)),
                pw.Divider(),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          _buildTable(tasks, periodsByTask, taskCats),
        ],
      ),
    );

    final dir = await _ensureDir();
    final file = File(p.join(dir.path,
        'jobtrackr_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf'));
    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  pw.Widget _buildTable(
    List<Task> tasks,
    Map<String, List<TaskPeriod>> periodsByTask,
    Map<String, List<TaskCategory>>? taskCats,
  ) {
    final headers = ['Task', 'Category', 'Sessions', 'Description'];
    final rows = <List<String>>[];

    for (final t in tasks) {
      final tPeriods = periodsByTask[t.id] ?? [];
      if (tPeriods.isEmpty) continue;
      final cats = taskCats?[t.id] ?? [];
      final catNames = cats.map((c) => c.name).join(', ');
      final sessions = tPeriods.map((tp) {
        return tp.isSingleDay
            ? _formatDate(tp.startDate)
            : '${_formatDate(tp.startDate)} — ${_formatDate(tp.endDate!)}';
      }).join('\n');
      rows.add([
        t.title,
        catNames,
        sessions,
        t.description ?? '',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.topLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      headers: headers,
      data: rows.map((r) => r as List<dynamic>).toList(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(3),
      },
    );
  }

  Future<String> generateCsv({
    required List<Task> tasks,
    required List<TaskPeriod> periods,
    required DateTime from,
    required DateTime to,
    String employeeName = '',
    String employeeId = '',
    String employeeTeam = '',
    Map<String, List<TaskCategory>>? taskCats,
  }) async {
    final rows = <List<dynamic>>[
      ['Job Accomplishments'],
      ['From ${_formatMonthYear(from)}  To  ${_formatMonthYear(to)}'],
      if (employeeName.isNotEmpty) ['Name: $employeeName'],
      if (employeeId.isNotEmpty) ['ID: $employeeId'],
      if (employeeTeam.isNotEmpty) ['Team: $employeeTeam'],
      [],
      ['Task', 'Category', 'Sessions', 'Description'],
    ];
    for (final t in tasks) {
      final tPeriods = periods.where((p) => p.taskId == t.id).toList();
      if (tPeriods.isEmpty) continue;
      final cats = taskCats?[t.id] ?? [];
      final catNames = cats.map((c) => c.name).join('; ');
      final sessions = tPeriods.map((tp) {
        return tp.isSingleDay
            ? _formatDate(tp.startDate)
            : '${_formatDate(tp.startDate)} — ${_formatDate(tp.endDate!)}';
      }).join('\n');
      rows.add([t.title, catNames, sessions, t.description ?? '']);
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
  String _formatMonthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);
}

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