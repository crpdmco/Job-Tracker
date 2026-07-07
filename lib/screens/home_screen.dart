import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task_category.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../services/db_service.dart';
import '../utils/time_utils.dart';
import '../widgets/task_category_chip.dart';
import 'task_form_screen.dart';
import 'task_detail_screen.dart';
import 'reports_screen.dart';
import 'categories_screen.dart';
import 'dashboard_screen.dart';

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
      const DashboardScreen(),
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
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Dashboard'),
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
        db.getActiveEntry(),
        db.getAllTaskCategories(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = (snap.data![0] as List<Task>);
        final active = snap.data![1] as TimeEntry?;
        final taskCats = snap.data![2] as Map<String, List<TaskCategory>>;
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
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    )),
                            Text('Your tasks',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    )),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),
              ),
              if (active != null)
                SliverToBoxAdapter(
                  child: _ActiveTimerCard(entry: active),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search tasks…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showArchived = !_showArchived),
                        icon: Icon(
                          _showArchived
                              ? Icons.archive
                              : Icons.archive_outlined,
                          size: 16,
                        ),
                        label: Text(
                            _showArchived ? 'Showing archived' : 'Show archived',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final t = filtered[i];
                      return _TaskCard(
                        task: t,
                        categories: taskCats[t.id] ?? const [],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
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
            Text('Tap "New Task" to start tracking your work.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ActiveTimerCard extends StatefulWidget {
  const _ActiveTimerCard({required this.entry});
  final TimeEntry entry;

  @override
  State<_ActiveTimerCard> createState() => _ActiveTimerCardState();
}

class _ActiveTimerCardState extends State<_ActiveTimerCard> {
  late Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: DbService.instance.getTask(widget.entry.taskId),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final task = snap.data!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fiber_manual_record,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    const Text('LIVE TIMER',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await DbService.instance.stopEntry(widget.entry.id);
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.stop_circle, color: Colors.white, size: 36),
                      tooltip: 'Stop',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(task.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(TimeUtils.formatDuration(widget.entry.duration),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w300,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(height: 8),
                Text('Started at ${TimeUtils.formatTime(widget.entry.startTime)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        );
      },
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
            content: const Text('This will also remove all its time entries.'),
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
          onLongPress: () async {
            HapticFeedback.mediumImpact();
            try {
              await DbService.instance.startEntry(task.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Timer started'),
                      duration: Duration(seconds: 1)),
                );
              }
            } catch (_) {}
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
                IconButton(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    try {
                      await DbService.instance.startEntry(task.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Timer started'),
                              duration: Duration(seconds: 1)),
                        );
                      }
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.play_circle_filled, size: 32),
                  color: Theme.of(context).colorScheme.primary,
                  tooltip: 'Start timer',
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
