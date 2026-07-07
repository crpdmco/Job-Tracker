import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/task_category.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../services/db_service.dart';
import '../utils/time_utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = DbService.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        DbService.instance.getAllEntries(),
        DbService.instance.getTasks(),
        DbService.instance.getCategories(),
        DbService.instance.getAllTaskCategories(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snap.data![0] as List<TimeEntry>;
        final tasks = snap.data![1] as List<Task>;
        final categories = snap.data![2] as List<TaskCategory>;
        final taskCats = snap.data![3] as Map<String, List<TaskCategory>>;
        return _DashboardBody(
            entries: entries,
            tasks: tasks,
            categories: categories,
            taskCats: taskCats);
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.entries,
    required this.tasks,
    required this.categories,
    required this.taskCats,
  });
  final List<TimeEntry> entries;
  final List<Task> tasks;
  final List<TaskCategory> categories;
  final Map<String, List<TaskCategory>> taskCats;

  @override
  Widget build(BuildContext context) {
    final catMap = {for (final c in categories) c.id: c};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 6));

    final todayEntries = entries
        .where((e) =>
            e.startTime.year == today.year &&
            e.startTime.month == today.month &&
            e.startTime.day == today.day)
        .toList();
    final weekEntries =
        entries.where((e) => e.startTime.isAfter(weekAgo)).toList();

    final todayTotal = todayEntries.fold(Duration.zero, (a, e) => a + e.duration);
    final weekTotal = weekEntries.fold(Duration.zero, (a, e) => a + e.duration);
    final grandTotal = entries.fold(Duration.zero, (a, e) => a + e.duration);

    // Last 7 days per-day
    final perDay = <int, Duration>{};
    for (var i = 0; i < 7; i++) {
      perDay[i] = Duration.zero;
    }
    for (final e in weekEntries) {
      final dayKey = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      final diff = dayKey.difference(weekAgo).inDays;
      if (diff >= 0 && diff < 7) {
        perDay[diff] = (perDay[diff] ?? Duration.zero) + e.duration;
      }
    }
    final maxBar = perDay.values.fold<double>(
        0, (m, d) => d.inMinutes > m ? d.inMinutes.toDouble() : m);
    final chartMax = (maxBar == 0 ? 60.0 : (maxBar * 1.2));

    // Per-category breakdown
    final byCategory = <String, Duration>{};
    for (final e in entries) {
      final cats = taskCats[e.taskId] ?? [];
      for (final cat in cats) {
        byCategory[cat.id] =
            (byCategory[cat.id] ?? Duration.zero) + e.duration;
      }
    }
    final catSorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Dashboard',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    label: 'Today',
                    value: TimeUtils.formatHoursCompact(todayTotal),
                    icon: Icons.today,
                    color: Colors.blue)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatCard(
                    label: 'This week',
                    value: TimeUtils.formatHoursCompact(weekTotal),
                    icon: Icons.date_range,
                    color: Colors.purple)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatCard(
                    label: 'All time',
                    value: TimeUtils.formatHoursCompact(grandTotal),
                    icon: Icons.access_time,
                    color: Colors.teal)),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last 7 days',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      maxY: chartMax,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i > 6) return const SizedBox.shrink();
                              final d = weekAgo.add(Duration(days: i));
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  TimeUtils.formatWeekday(d),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(7, (i) {
                        final v = perDay[i]!.inMinutes.toDouble();
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: v,
                              color: Theme.of(context).colorScheme.primary,
                              width: 18,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By category',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 12),
                if (catSorted.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No data yet.'),
                  )
                else
                  ...catSorted.map((entry) {
                    final cat = catMap[entry.key];
                    final pct = grandTotal.inSeconds == 0
                        ? 0.0
                        : entry.value.inSeconds / grandTotal.inSeconds;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: cat?.color ?? Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(cat?.name ?? 'Unknown')),
                              Text(
                                  '${(pct * 100).toStringAsFixed(0)}%  ·  ${TimeUtils.formatHoursCompact(entry.value)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                              valueColor: AlwaysStoppedAnimation(
                                  cat?.color ?? Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
