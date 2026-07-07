class TimeEntry {
  final String id;
  final String taskId;
  final DateTime startTime;
  final DateTime? endTime;
  final String? note;
  final DateTime createdAt;

  TimeEntry({
    required this.id,
    required this.taskId,
    required this.startTime,
    this.endTime,
    this.note,
    required this.createdAt,
  });

  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  bool get isActive => endTime == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TimeEntry.fromMap(Map<String, dynamic> m) => TimeEntry(
        id: m['id'] as String,
        taskId: m['taskId'] as String,
        startTime: DateTime.parse(m['startTime'] as String),
        endTime: m['endTime'] != null
            ? DateTime.parse(m['endTime'] as String)
            : null,
        note: m['note'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}
