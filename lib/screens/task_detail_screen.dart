import 'dart:async';
import 'package:flutter/material.dart';

import '../models/task_category.dart';
import '../models/task.dart';
import '../models/task_period.dart';
import '../services/db_service.dart';
import '../utils/time_utils.dart';
import '../widgets/task_category_chip.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
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
        DbService.instance.getTask(widget.taskId),
        DbService.instance.getTaskCategories(widget.taskId),
        DbService.instance.getPeriodsForTask(widget.taskId),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final task = snap.data![0] as Task?;
        if (task == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Task deleted')),
          );
        }
        final taskCategories = snap.data![1] as List<TaskCategory>;
        final periods = snap.data![2] as List<TaskPeriod>;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Task'),
            actions: [
              IconButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            TaskFormScreen(existing: task)),
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete task?'),
                      content: const Text(
                          'This will also remove all associated dates.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        FilledButton.tonal(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await DbService.instance.deleteTask(task.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(task.title,
                  style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
              const SizedBox(height: 8),
              _CategoryChips(
                  categories: taskCategories, periodsCount: periods.length),
              if (task.description != null) ...[
                const SizedBox(height: 12),
                Text(task.description!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 20),
              _SectionHeader(title: 'Dates'),
              const SizedBox(height: 8),
              if (periods.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('No dates set.')),
                )
              else
                ...periods.map((p) => _PeriodTile(period: p)),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({required this.period});
  final TaskPeriod period;

  @override
  Widget build(BuildContext context) {
    final isRange = !period.isSingleDay;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            isRange ? Icons.date_range : Icons.today,
            size: 18,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          isRange
              ? '${TimeUtils.formatDate(period.startDate)}  →  ${TimeUtils.formatDate(period.endDate!)}'
              : TimeUtils.formatDate(period.startDate),
        ),
        subtitle: period.note != null ? Text(period.note!) : null,
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.periodsCount,
  });
  final List<TaskCategory> categories;
  final int periodsCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        ...categories.map((c) => TaskCategoryChip(category: c)),
        Chip(
          avatar: const Icon(Icons.date_range, size: 14),
          label: Text(
            '$periodsCount period${periodsCount == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}