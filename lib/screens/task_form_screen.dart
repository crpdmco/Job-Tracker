import 'package:flutter/material.dart';

import '../models/task_category.dart';
import '../models/task.dart';
import '../models/task_period.dart';
import '../services/db_service.dart';
import '../utils/time_utils.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.existing});
  final Task? existing;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _title;
  late TextEditingController _description;
  String? _categoryId;
  late List<_PeriodDraft> _periods;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _title = TextEditingController(text: t?.title ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _categoryId = t?.categoryId;
    _periods = [];
    if (widget.existing != null) {
      _loadPeriods();
    }
  }

  Future<void> _loadPeriods() async {
    final periods =
        await DbService.instance.getPeriodsForTask(widget.existing!.id);
    setState(() {
      _periods = periods
          .map((p) => _PeriodDraft(
              startDate: p.startDate,
              endDate: p.endDate,
              note: p.note,
              existingId: p.id))
          .toList();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_periods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one period or day.')),
      );
      return;
    }
    try {
      final db = DbService.instance;
      final task = Task(
        id: widget.existing?.id ?? '',
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        categoryId: _categoryId,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      Task saved;
      if (widget.existing == null) {
        saved = await db.createTask(task);
      } else {
        await db.updateTask(task);
        saved = task;
      }

      // Sync periods: remove existing, re-add current drafts
      if (widget.existing != null) {
        final existing =
            await db.getPeriodsForTask(widget.existing!.id);
        for (final p in existing) {
          await db.deletePeriod(p.id);
        }
      }
      for (final d in _periods) {
        await db.createPeriod(TaskPeriod(
          id: d.existingId ?? '',
          taskId: saved.id,
          startDate: d.startDate,
          endDate: d.endDate,
          note: d.note,
          createdAt: DateTime.now(),
        ));
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task: $e')),
        );
      }
    }
  }

  void _addPeriod() {
    setState(() {
      _periods.add(_PeriodDraft(
        startDate: DateTime.now(),
        endDate: null,
        note: null,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Task' : 'Edit Task'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Task name',
                hintText: 'e.g. Build login screen',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Category'),
            const SizedBox(height: 8),
            FutureBuilder<List<TaskCategory>>(
              future: DbService.instance.getCategories(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cats = snap.data!;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CategoryChoice(
                      label: 'None',
                      color: Colors.grey,
                      selected: _categoryId == null,
                      onTap: () => setState(() => _categoryId = null),
                    ),
                    ...cats.map((c) => _CategoryChoice(
                          label: c.name,
                          color: c.color,
                          selected: _categoryId == c.id,
                          onTap: () => setState(() => _categoryId = c.id),
                        )),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Periods & Days'),
            const SizedBox(height: 4),
            Text(
              'Add the date ranges or individual days this task covers.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            if (_periods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No periods added yet.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ..._periods.asMap().entries.map((entry) {
                final i = entry.key;
                final d = entry.value;
                return _PeriodCard(
                  index: i,
                  draft: d,
                  onChange: () => setState(() {}),
                  onRemove: () => setState(() => _periods.removeAt(i)),
                );
              }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addPeriod,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add period or day'),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(widget.existing == null
                  ? 'Create task'
                  : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodDraft {
  DateTime startDate;
  DateTime? endDate;
  String? note;
  String? existingId;

  _PeriodDraft({
    required this.startDate,
    this.endDate,
    this.note,
    this.existingId,
  });
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

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
              color: selected ? color : Theme.of(context).dividerColor,
              width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _PeriodCard extends StatefulWidget {
  const _PeriodCard({
    required this.index,
    required this.draft,
    required this.onChange,
    required this.onRemove,
  });
  final int index;
  final _PeriodDraft draft;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  State<_PeriodCard> createState() => _PeriodCardState();
}

class _PeriodCardState extends State<_PeriodCard> {
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.draft.note ?? '');
    _noteCtrl.addListener(() {
      widget.draft.note =
          _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final isRange = d.endDate != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRange ? 'RANGE' : 'SINGLE DAY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Start',
                    value: d.startDate,
                    onChanged: (dt) {
                      if (dt != null) {
                        setState(() {
                          widget.draft.startDate = dt;
                          widget.onChange();
                        });
                      }
                    },
                  ),
                ),
                if (isRange) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                  Expanded(
                    child: _DateTile(
                      label: 'End',
                      value: d.endDate!,
                      onChanged: (dt) {
                        if (dt != null) {
                          setState(() {
                            widget.draft.endDate = dt;
                            widget.onChange();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (!isRange)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        widget.draft.endDate = widget.draft.startDate;
                        widget.onChange();
                      });
                    },
                    icon: const Icon(Icons.date_range, size: 16),
                    label: const Text('Make range', style: TextStyle(fontSize: 12)),
                  )
                else
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        widget.draft.endDate = null;
                        widget.onChange();
                      });
                    },
                    icon: const Icon(Icons.today, size: 16),
                    label: const Text('Make single day', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                hintText: 'Note (optional)',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(TimeUtils.formatDate(value),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
