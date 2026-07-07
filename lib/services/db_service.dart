import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:uuid/uuid.dart';

import '../models/task_category.dart';
import '../models/task.dart';
import '../models/task_period.dart';
import '../models/time_entry.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  Database? _db;
  final _uuid = const Uuid();
  final _changes = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();

  Stream<void> get changes => _changes.stream;
  Stream<String> get errors => _errors.stream;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (kIsWeb) {
      databaseFactory = createDatabaseFactoryFfiWeb();
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = kIsWeb
        ? 'jobtrackr.db'
        : p.join(await getDatabasesPath(), 'jobtrackr.db');
    return openDatabase(
      dbPath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        iconName TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        categoryId TEXT,
        createdAt TEXT NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE task_periods (
        id TEXT PRIMARY KEY,
        taskId TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT,
        note TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (taskId) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE time_entries (
        id TEXT PRIMARY KEY,
        taskId TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        note TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE task_categories (
        taskId TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        PRIMARY KEY (taskId, categoryId)
      )
    ''');
    await _seedDefaults(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      // Create task_periods table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_periods (
          id TEXT PRIMARY KEY,
          taskId TEXT NOT NULL,
          startDate TEXT NOT NULL,
          endDate TEXT,
          note TEXT,
          createdAt TEXT NOT NULL
        )
      ''');

      // Migrate existing tasks: create a period from their startDate/endDate
      final oldTasks = await db.rawQuery(
          'SELECT id, startDate, endDate, createdAt FROM tasks WHERE startDate IS NOT NULL');
      for (final row in oldTasks) {
        await db.insert('task_periods', {
          'id': _uuid.v4(),
          'taskId': row['id'] as String,
          'startDate': row['startDate'] as String,
          'endDate': row['endDate'] as String?,
          'note': null,
          'createdAt': row['createdAt'] as String,
        });
      }
    }
    if (oldV < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_categories (
          taskId TEXT NOT NULL,
          categoryId TEXT NOT NULL,
          PRIMARY KEY (taskId, categoryId)
        )
      ''');
      // Migrate existing categoryId from tasks table
      final existing = await db.rawQuery(
          'SELECT id, categoryId FROM tasks WHERE categoryId IS NOT NULL');
      for (final row in existing) {
        await db.insert('task_categories', {
          'taskId': row['id'] as String,
          'categoryId': row['categoryId'] as String,
        });
      }
    }
  }

  Future<void> _seedDefaults(Database db) async {
    final defaults = [
      TaskCategory(id: _uuid.v4(), name: 'Work', colorValue: 0xFF3B82F6, iconName: 'work'),
      TaskCategory(id: _uuid.v4(), name: 'Code', colorValue: 0xFF10B981, iconName: 'code'),
      TaskCategory(id: _uuid.v4(), name: 'Design', colorValue: 0xFFA855F7, iconName: 'design'),
      TaskCategory(id: _uuid.v4(), name: 'Meeting', colorValue: 0xFFF59E0B, iconName: 'meeting'),
    ];
    for (final c in defaults) {
      await db.insert('categories', c.toMap());
    }
  }

  // ---- Categories ----
  Future<List<TaskCategory>> getCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map(TaskCategory.fromMap).toList();
  }

  Future<TaskCategory> createCategory(
      String name, int colorValue, String iconName) async {
    try {
      final db = await database;
      final c = TaskCategory(
        id: _uuid.v4(),
        name: name,
        colorValue: colorValue,
        iconName: iconName,
      );
      await db.insert('categories', c.toMap());
      _changes.add(null);
      return c;
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  Future<void> updateCategory(TaskCategory c) async {
    try {
      final db = await database;
      await db.update(
          'categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
      _changes.add(null);
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      final db = await database;
      await db.delete('categories', where: 'id = ?', whereArgs: [id]);
      _changes.add(null);
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  // ---- Tasks ----
  Future<List<Task>> getTasks({bool includeArchived = false}) async {
    final db = await database;
    final rows = await db.query(
      'tasks',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'createdAt DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> getTask(String id) async {
    final db = await database;
    final rows = await db.query(
        'tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<Task> createTask(Task t) async {
    try {
      final db = await database;
      final withId = Task(
        id: t.id.isEmpty ? _uuid.v4() : t.id,
        title: t.title,
        description: t.description,
        createdAt: t.createdAt,
      );
      await db.insert('tasks', withId.toMap());
      _changes.add(null);
      return withId;
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  Future<void> updateTask(Task t) async {
    try {
      final db = await database;
      await db.update('tasks', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
      _changes.add(null);
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      final db = await database;
      await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
      await db.delete(
          'task_periods', where: 'taskId = ?', whereArgs: [id]);
      await db.delete('time_entries', where: 'taskId = ?', whereArgs: [id]);
      await db.delete(
          'task_categories', where: 'taskId = ?', whereArgs: [id]);
      _changes.add(null);
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  // ---- Task categories (tags) ----
  Future<List<TaskCategory>> getTaskCategories(String taskId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT c.* FROM categories c
      INNER JOIN task_categories tc ON c.id = tc.categoryId
      WHERE tc.taskId = ?
      ORDER BY c.name ASC
    ''', [taskId]);
    return rows.map(TaskCategory.fromMap).toList();
  }

  Future<List<String>> getTaskCategoryIds(String taskId) async {
    final db = await database;
    final rows = await db.query('task_categories',
        where: 'taskId = ?', whereArgs: [taskId]);
    return rows.map((r) => r['categoryId'] as String).toList();
  }

  /// Returns a map of taskId → list of categories for all tasks.
  Future<Map<String, List<TaskCategory>>> getAllTaskCategories() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT tc.taskId, c.* FROM task_categories tc
      INNER JOIN categories c ON c.id = tc.categoryId
      ORDER BY c.name ASC
    ''');
    final map = <String, List<TaskCategory>>{};
    for (final row in rows) {
      final taskId = row['taskId'] as String;
      final cat = TaskCategory.fromMap(row);
      map.putIfAbsent(taskId, () => []).add(cat);
    }
    return map;
  }

  Future<void> setTaskCategories(
      String taskId, List<String> categoryIds) async {
    try {
      final db = await database;
      await db.delete('task_categories', where: 'taskId = ?', whereArgs: [taskId]);
      for (final catId in categoryIds) {
        await db.insert(
            'task_categories', {'taskId': taskId, 'categoryId': catId});
      }
      _changes.add(null);
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  // ---- Task periods ----
  Future<List<TaskPeriod>> getPeriodsForTask(String taskId) async {
    final db = await database;
    final rows = await db.query(
      'task_periods',
      where: 'taskId = ?',
      whereArgs: [taskId],
      orderBy: 'startDate ASC',
    );
    return rows.map(TaskPeriod.fromMap).toList();
  }

  Future<TaskPeriod> createPeriod(TaskPeriod p) async {
    try {
      final db = await database;
      final withId = TaskPeriod(
        id: _uuid.v4(),
        taskId: p.taskId,
        startDate: p.startDate,
        endDate: p.endDate,
        note: p.note,
        createdAt: p.createdAt,
      );
      await db.insert('task_periods', withId.toMap());
      _changes.add(null);
      return withId;
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  Future<void> updatePeriod(TaskPeriod p) async {
    try {
      final db = await database;
      await db.update('task_periods', p.toMap(),
          where: 'id = ?', whereArgs: [p.id]);
      _changes.add(null);
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  Future<void> deletePeriod(String id) async {
    try {
      final db = await database;
      await db.delete('task_periods', where: 'id = ?', whereArgs: [id]);
      _changes.add(null);
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  // ---- Time entries ----
  Future<List<TimeEntry>> getEntriesForTask(String taskId) async {
    final db = await database;
    final rows = await db.query(
      'time_entries',
      where: 'taskId = ?',
      whereArgs: [taskId],
      orderBy: 'startTime DESC',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<List<TimeEntry>> getAllEntries({DateTime? from, DateTime? to}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('startTime >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('startTime <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query(
      'time_entries',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'startTime DESC',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<TimeEntry?> getActiveEntry() async {
    final db = await database;
    final rows = await db.query(
      'time_entries',
      where: 'endTime IS NULL',
      orderBy: 'startTime DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TimeEntry.fromMap(rows.first);
  }

  Future<TimeEntry> startEntry(String taskId) async {
    try {
      final db = await database;
      await db.update(
        'time_entries',
        {'endTime': DateTime.now().toIso8601String()},
        where: 'endTime IS NULL',
      );
      final e = TimeEntry(
        id: _uuid.v4(),
        taskId: taskId,
        startTime: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await db.insert('time_entries', e.toMap());
      _changes.add(null);
      return e;
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  Future<void> stopEntry(String id, {String? note}) async {
    try {
      final db = await database;
      await db.update(
        'time_entries',
        {'endTime': DateTime.now().toIso8601String(), 'note': note},
        where: 'id = ?',
        whereArgs: [id],
      );
      _changes.add(null);
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      final db = await database;
      await db.delete('time_entries', where: 'id = ?', whereArgs: [id]);
      _changes.add(null);
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }

  Future<void> updateEntry(TimeEntry e) async {
    try {
      final db = await database;
      await db.update(
          'time_entries', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
      _changes.add(null);
    } catch (e) {
      _errors.add(e.toString());
      rethrow;
    }
  }
}
