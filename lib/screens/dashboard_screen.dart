import 'dart:async';
import 'package:flutter/material.dart';

import '../models/task_category.dart';
import '../models/task.dart';
import '../services/db_service.dart';


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
        DbService.instance.getTasks(),
        DbService.instance.getCategories(),
        DbService.instance.getAllPeriods(),
        DbService.instance.getAllTaskCategories(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = snap.data![0] as List<Task>;
        final categories = snap.data![1] as List<TaskCategory>;
        final periods = snap.data![2] as List;
        final taskCats = snap.data![3] as Map<String, List<TaskCategory>>;
        return _DashboardBody(
            tasks: tasks,
            categories: categories,
            periods: periods,
            taskCats: taskCats);
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.tasks,
    required this.categories,
    required this.periods,
    required this.taskCats,
  });
  final List<Task> tasks;
  final List<TaskCategory> categories;
  final List periods;
  final Map<String, List<TaskCategory>> taskCats;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, int>{};
    for (final t in tasks) {
      final cats = taskCats[t.id] ?? [];
      for (final cat in cats) {
        byCategory[cat.id] = (byCategory[cat.id] ?? 0) + 1;
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
                    label: 'Tasks',
                    value: '${tasks.length}',
                    icon: Icons.checklist,
                    color: Colors.blue)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatCard(
                    label: 'Dates',
                    value: '${periods.length}',
                    icon: Icons.date_range,
                    color: Colors.purple)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatCard(
                    label: 'Categories',
                    value: '${categories.length}',
                    icon: Icons.label,
                    color: Colors.teal)),
          ],
        ),
        const SizedBox(height: 24),
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
                    child: Text('No tasks with categories yet.'),
                  )
                else
                  ...catSorted.map((entry) {
                    final cat = categories.firstWhere(
                        (c) => c.id == entry.key,
                        orElse: () => TaskCategory(
                            id: '',
                            name: 'Unknown',
                            colorValue: 0xFF9E9E9E));
                    final pct = tasks.isEmpty
                        ? 0.0
                        : entry.value / tasks.length;
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
                                  color: cat.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(cat.name)),
                              Text(
                                  '${entry.value} task${entry.value == 1 ? '' : 's'}',
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
                              valueColor: AlwaysStoppedAnimation(cat.color),
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