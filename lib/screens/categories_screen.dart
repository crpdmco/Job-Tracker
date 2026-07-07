import 'dart:async';
import 'package:flutter/material.dart';

import '../models/task_category.dart';
import '../services/db_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<TaskCategory> _cats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cats = await DbService.instance.getCategories();
    if (mounted) setState(() { _cats = cats; _loading = false; });
  }

  Future<void> _edit({TaskCategory? existing}) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CategoryEditor(existing: existing),
    );
    if (result == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Categories',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_cats.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No categories yet.')),
              )
            else
              ..._cats.map((c) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c.color.withValues(alpha: 0.18),
                        child: Icon(c.icon, color: c.color),
                      ),
                      title: Text(c.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await DbService.instance.deleteCategory(c.id);
                          if (mounted) _load();
                        },
                      ),
                      onTap: () => _edit(existing: c),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({this.existing});
  final TaskCategory? existing;
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late TextEditingController _name;
  late int _color;
  late String _icon;

  static const _colors = [
    0xFF3B82F6, 0xFF10B981, 0xFFA855F7, 0xFFF59E0B,
    0xFFEF4444, 0xFF14B8A6, 0xFFEC4899, 0xFF6366F1,
    0xFF22C55E, 0xFFF97316, 0xFF8B5CF6, 0xFF0EA5E9,
  ];
  static const _icons = [
    ('work', Icons.work_outline),
    ('code', Icons.code),
    ('design', Icons.palette),
    ('meeting', Icons.groups),
    ('bug', Icons.bug_report),
    ('research', Icons.search),
    ('writing', Icons.edit_note),
    ('admin', Icons.folder),
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.colorValue ?? _colors.first;
    _icon = widget.existing?.iconName ?? 'work';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'New category' : 'Edit category',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            const Text('Color',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colors.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Icon',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _icons.map((e) {
                final selected = e.$1 == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = e.$1),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? Color(_color).withValues(alpha: 0.2)
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              selected ? Color(_color) : Colors.transparent,
                          width: 2),
                    ),
                    child: Icon(e.$2, color: Color(_color)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final name = _name.text.trim();
                      if (name.isEmpty) return;
                      final ctx = context;
                      final db = DbService.instance;
                      if (widget.existing == null) {
                        await db.createCategory(name, _color, _icon);
                      } else {
                        await db.updateCategory(widget.existing!.copyWith(
                            name: name,
                            colorValue: _color,
                            iconName: _icon));
                      }
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
