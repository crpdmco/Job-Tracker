import 'package:flutter/material.dart';

import '../services/db_service.dart';
import '../services/report_service.dart';
import '../utils/time_utils.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _from;
  late DateTime _to;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _from = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 30));
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _to = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  void _setRange(DateTime from, DateTime to) {
    setState(() {
      _from = from;
      _to = to;
    });
  }

  Future<void> _export({required bool pdf}) async {
    setState(() => _busy = true);
    try {
      final db = DbService.instance;
      final tasks = await db.getTasks(includeArchived: true);
      final categories = await db.getCategories();
      final entries = await db.getAllEntries(from: _from, to: _to);
      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No sessions in this period.')),
          );
        }
        return;
      }
      final svc = ReportService();
      final taskCats = await db.getAllTaskCategories();
      final path = pdf
          ? await svc.generatePdf(
              tasks: tasks,
              categories: categories,
              entries: entries,
              from: _from,
              to: _to,
              taskCats: taskCats,
            )
          : await svc.generateCsv(
              tasks: tasks,
              entries: entries,
              from: _from,
              to: _to,
            );
      if (mounted) {
        await svc.share(path);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Reports',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: 8),
        Text(
          'Generate an accomplishment report from your time entries.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Period'),
            subtitle: Text(
                '${TimeUtils.formatDate(_from)}  →  ${TimeUtils.formatDate(_to)}'),
            trailing: const Icon(Icons.edit),
            onTap: _pickRange,
          ),
        ),
        const SizedBox(height: 20),
        _Preset(label: 'Today', onTap: () {
          final n = DateTime.now();
          _setRange(
            DateTime(n.year, n.month, n.day),
            DateTime(n.year, n.month, n.day, 23, 59, 59),
          );
        }),
        _Preset(label: 'Yesterday', onTap: () {
          final n = DateTime.now().subtract(const Duration(days: 1));
          _setRange(
            DateTime(n.year, n.month, n.day),
            DateTime(n.year, n.month, n.day, 23, 59, 59),
          );
        }),
        _Preset(label: 'Last 7 days', onTap: () {
          final n = DateTime.now();
          _setRange(
            DateTime(n.year, n.month, n.day)
                .subtract(const Duration(days: 6)),
            DateTime(n.year, n.month, n.day, 23, 59, 59),
          );
        }),
        _Preset(label: 'Last 30 days', onTap: () {
          final n = DateTime.now();
          _setRange(
            DateTime(n.year, n.month, n.day)
                .subtract(const Duration(days: 29)),
            DateTime(n.year, n.month, n.day, 23, 59, 59),
          );
        }),
        _Preset(label: 'This month', onTap: () {
          final n = DateTime.now();
          _setRange(
            DateTime(n.year, n.month, 1),
            DateTime(n.year, n.month, n.day, 23, 59, 59),
          );
        }),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : () => _export(pdf: true),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Export PDF report'),
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _export(pdf: false),
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('Export CSV'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54)),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
