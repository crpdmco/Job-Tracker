import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/task_category.dart';
import '../models/task.dart';
import '../models/task_period.dart';

class ReportService {
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

    final dataFrom = periods
        .map((p) => p.startDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final dataTo = periods
        .map((p) => p.endDate ?? p.startDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);

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
                pw.Text('Job Accomplishments Report',
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                  'From ${_formatMonthYear(dataFrom)}  To  ${_formatMonthYear(dataTo)}',
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

    final bytes = await doc.save();
    final loc = await getSaveLocation(
      suggestedName:
          'jobtrackr_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      acceptedTypeGroups: [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (loc == null) throw Exception('Save cancelled');
    await File(loc.path).writeAsBytes(bytes);
    return loc.path;
  }

  pw.Widget _buildTable(
    List<Task> tasks,
    Map<String, List<TaskPeriod>> periodsByTask,
    Map<String, List<TaskCategory>>? taskCats,
  ) {
    const cellPad = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4);
    const cellStyle = pw.TextStyle(fontSize: 9);
    final headerStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
    final tableBorder = pw.TableBorder.all(
      color: PdfColors.grey400,
      width: 0.5,
    );

    pw.Widget cell(String text) => pw.Padding(
          padding: cellPad,
          child: pw.Text(text, style: cellStyle),
        );

    pw.Widget headerCell(String text) => pw.Container(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(text, style: headerStyle),
        );

    pw.Widget sessionsCell(List<TaskPeriod> tPeriods) {
      final lines = tPeriods.map((tp) {
        final date = tp.isSingleDay
            ? _formatDate(tp.startDate)
            : '${_formatDate(tp.startDate)} - ${_formatDate(tp.endDate!)}';
        return '- $date';
      }).toList();
      return pw.Padding(
        padding: cellPad,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: lines.map((l) => pw.Text(l, style: cellStyle)).toList(),
        ),
      );
    }

    final header = pw.TableRow(children: [
      headerCell('Task'),
      headerCell('Category'),
      headerCell('Sessions'),
      headerCell('Description'),
    ]);

    final dataRows = <pw.TableRow>[];
    for (final t in tasks) {
      final tPeriods = periodsByTask[t.id] ?? [];
      if (tPeriods.isEmpty) continue;
      final cats = taskCats?[t.id] ?? [];
      final catNames = cats.map((c) => c.name).join(', ');
      dataRows.add(pw.TableRow(
        children: [
          cell(t.title),
          cell(catNames),
          sessionsCell(tPeriods),
          cell(t.description ?? ''),
        ],
      ));
    }

    return pw.Table(
      border: tableBorder,
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(3),
      },
      children: [header, ...dataRows],
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
    final dataFrom = periods
        .map((p) => p.startDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final dataTo = periods
        .map((p) => p.endDate ?? p.startDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final rows = <List<dynamic>>[
      ['Job Accomplishments Report'],
      ['From ${_formatMonthYear(dataFrom)}  To  ${_formatMonthYear(dataTo)}'],
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
        final date = tp.isSingleDay
            ? _formatDate(tp.startDate)
            : '${_formatDate(tp.startDate)} - ${_formatDate(tp.endDate!)}';
        return '- $date';
      }).join('\n');
      rows.add([t.title, catNames, sessions, t.description ?? '']);
    }
    final csv = ListToCsvConverter().convert(rows);
    final loc = await getSaveLocation(
      suggestedName:
          'jobtrackr_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      acceptedTypeGroups: [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (loc == null) throw Exception('Save cancelled');
    await File(loc.path).writeAsString(csv);
    return loc.path;
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