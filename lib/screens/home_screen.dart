import 'dart:async';
import 'package:flutter/material.dart';

import '../models/task_category.dart';
import '../models/task.dart';
import '../services/db_service.dart';
import '../utils/time_utils.dart';
import '../widgets/task_category_chip.dart';
import 'task_form_screen.dart';
import 'task_detail_screen.dart';
import 'reports_screen.dart';
import 'categories_screen.dart';
import 'employee_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late final StreamSubscription _sub;
  late final StreamSubscription _errSub;

  @override
  void initState() {
    super.initState();
    _sub = DbService.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _errSub = DbService.instance.errors.listen((msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _errSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _TasksTab(),
      const EmployeeScreen(),
      const CategoriesScreen(),
      const ReportsScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TaskFormScreen()),
                );
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.add),
              label: const Text('New Task'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Tasks'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Employee'),
          NavigationDestination(
              icon: Icon(Icons.label_outline),
              selectedIcon: Icon(Icons.label),
              label: 'Categories'),
          NavigationDestination(
              icon: Icon(Icons.summarize_outlined),
              selectedIcon: Icon(Icons.summarize),
              label: 'Reports'),
        ],
      ),
    );
  }
}

class _TasksTab extends StatefulWidget {
  const _TasksTab();
  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  bool _showArchived = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return FutureBuilder(
      key: ValueKey(_refreshKey),
      future: Future.wait([
        db.getTasks(includeArchived: _showArchived),
        db.getAllTaskCategories(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = (snap.data![0] as List<Task>);
        final taskCats = snap.data![1] as Map<String, List<TaskCategory>>;
        var filtered = tasks;
        if (_searchQuery.isNotEmpty) {
          filtered = filtered
              .where((t) => t.title.toLowerCase().contains(_searchQuery))
              .toList();
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello 👋',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                              tasks.length == 1
                                  ? '1 task'
                                  : '${tasks.length} tasks',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _showArchived = !_showArchived),
                        icon: Icon(
                          _showArchived
                              ? Icons.archive
                              : Icons.archive_outlined,
                        ),
                        tooltip: _showArchived
                            ? 'Hide archived'
                            : 'Show archived',
                      ),
                    ],
                  ),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Text(
                      '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final t = filtered[i];
                      return Padding(
                        padding: EdgeInsets.only(
                          top: i == 0 ? 4 : 0,
                          bottom: 8,
                        ),
                        child: _TaskCard(
                          task: t,
                          categories: taskCats[t.id] ?? const [],
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(child: _emptyState(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No tasks yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Tap "New Task" to get started.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.categories});
  final Task task;
  final List<TaskCategory> categories;

  @override
  Widget build(BuildContext context) {
    final color = categories.isNotEmpty
        ? categories.first.color
        : Theme.of(context).colorScheme.primary;
    return Dismissible(
      key: ValueKey(task.id),
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
            title: const Text('Delete task?'),
            content: const Text(
                'This will also remove all associated dates.'),
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
      onDismissed: (_) => DbService.instance.deleteTask(task.id),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(taskId: task.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                      categories.isNotEmpty ? categories.first.icon : Icons.work_outline,
                      color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...categories.take(2).map((c) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: TaskCategoryChip(
                                    category: c, small: true),
                              )),
                          if (categories.length > 2)
                            Text('+${categories.length - 2}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                          if (categories.isNotEmpty)
                            const SizedBox(width: 6),
                          _PeriodMiniBadge(taskId: task.id),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodMiniBadge extends StatelessWidget {
  const _PeriodMiniBadge({required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: DbService.instance.getPeriodsForTask(taskId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final periods = snap.data!;
        final first = periods.first;
        final isRange = !first.isSingleDay;
        final label = isRange
            ? '${TimeUtils.formatDateShort(first.startDate)}–${TimeUtils.formatDateShort(first.endDate!)}'
            : TimeUtils.formatDateShort(first.startDate);
        final extra = periods.length > 1 ? ' +${periods.length - 1}' : '';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRange ? Icons.date_range : Icons.today,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Text(
              '$label$extra',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}