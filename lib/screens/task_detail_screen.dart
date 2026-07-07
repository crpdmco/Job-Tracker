import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task_category.dart';
import '../models/task.dart';
import '../models/task_period.dart';
import '../models/time_entry.dart';
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
        DbService.instance.getCategories(),
        DbService.instance.getEntriesForTask(widget.taskId),
        DbService.instance.getActiveEntry(),
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
        final categories = snap.data![1] as List<TaskCategory>;
        final entries = snap.data![2] as List<TimeEntry>;
        final active = snap.data![3] as TimeEntry?;
        final periods = snap.data![4] as List<TaskPeriod>;
        final catMap = {for (final c in categories) c.id: c};
        final total =
            entries.fold(Duration.zero, (a, e) => a + e.duration);
        final isThisActive = active?.taskId == task.id;

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
                          'This will also remove all its time entries.'),
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
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (catMap[task.categoryId] != null)
                    TaskCategoryChip(
                        category: catMap[task.categoryId]!),
                  Chip(
                    avatar: const Icon(Icons.date_range, size: 14),
                    label: Text(
                      '${periods.length} period${periods.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (task.description != null) ...[
                const SizedBox(height: 12),
                Text(task.description!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: _StatTile(
                          label: 'Total time',
                          value: TimeUtils.formatHoursCompact(total))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatTile(
                          label: 'Sessions',
                          value: '${entries.length}')),
                ],
              ),
              const SizedBox(height: 24),
              if (isThisActive)
                FilledButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final note = await _askNote(context);
                    await DbService.instance
                        .stopEntry(active!.id, note: note);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop active session'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50)),
                )
              else
                FilledButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await DbService.instance.startEntry(task.id);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start timer'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                ),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Periods'),
              const SizedBox(height: 8),
              if (periods.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('No periods set.')),
                )
              else
                ...periods.map((p) => _PeriodTile(period: p)),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Sessions'),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No sessions logged yet.')),
                )
              else
                ...entries.map((e) => _EntryTile(entry: e)),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _askNote(BuildContext context) async {
    final c = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Session note (optional)'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'What did you accomplish?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Skip')),
          FilledButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Stop & save')),
        ],
      ),
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
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

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final TimeEntry entry;
  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete entry?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton.tonal(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete')),
            ],
          ),
        );
      },
      onDismissed: (_) {
        DbService.instance.deleteEntry(entry.id);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              entry.isActive ? Icons.fiber_manual_record : Icons.history,
              color: entry.isActive ? Colors.red : null,
              size: 18,
            ),
          ),
          title: Text(TimeUtils.formatDate(entry.startTime)),
          subtitle: Text(
              '${TimeUtils.formatTime(entry.startTime)}  →  ${entry.endTime != null ? TimeUtils.formatTime(entry.endTime!) : 'ongoing'}'),
          trailing: Text(TimeUtils.formatHoursCompact(entry.duration),
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          onTap: () => _editEntry(context, entry),
        ),
      ),
    );
  }

  Future<void> _editEntry(BuildContext context, TimeEntry entry) async {
    if (entry.isActive) return;
    DateTime start = entry.startTime;
    DateTime end = entry.endTime!;
    String? note = entry.note;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: const Text('Start time'),
                  subtitle: Text(TimeUtils.formatDateTime(start)),
                  onTap: () async {
                    final dt = await showDatePicker(
                      context: ctx,
                      initialDate: start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (dt == null) return;
                    if (!ctx.mounted) return;
                    final tm = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(start),
                    );
                    if (tm == null) return;
                    setDialogState(() => start = DateTime(
                        dt.year, dt.month, dt.day, tm.hour, tm.minute));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.stop),
                  title: const Text('End time'),
                  subtitle: Text(TimeUtils.formatDateTime(end)),
                  onTap: () async {
                    final dt = await showDatePicker(
                      context: ctx,
                      initialDate: end,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (dt == null) return;
                    if (!ctx.mounted) return;
                    final tm = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(end),
                    );
                    if (tm == null) return;
                    setDialogState(() => end = DateTime(
                        dt.year, dt.month, dt.day, tm.hour, tm.minute));
                  },
                ),
                if (end.isBefore(start)) ...[
                  const SizedBox(height: 8),
                  Text('End must be after start',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: note ?? ''),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    isDense: true,
                  ),
                  onChanged: (v) => note = v.trim().isEmpty ? null : v.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: end.isBefore(start)
                  ? null
                  : () {
                      DbService.instance.updateEntry(
                        TimeEntry(
                          id: entry.id,
                          taskId: entry.taskId,
                          startTime: start,
                          endTime: end,
                          note: note,
                          createdAt: entry.createdAt,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
