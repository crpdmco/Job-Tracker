class TaskPeriod {
  final String id;
  final String taskId;
  final DateTime startDate;
  final DateTime? endDate;
  final String? note;
  final DateTime createdAt;

  TaskPeriod({
    required this.id,
    required this.taskId,
    required this.startDate,
    this.endDate,
    this.note,
    required this.createdAt,
  });

  bool get isSingleDay => endDate == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskPeriod.fromMap(Map<String, dynamic> m) => TaskPeriod(
        id: m['id'] as String,
        taskId: m['taskId'] as String,
        startDate: DateTime.parse(m['startDate'] as String),
        endDate: m['endDate'] != null
            ? DateTime.parse(m['endDate'] as String)
            : null,
        note: m['note'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );

  TaskPeriod copyWith({
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    String? note,
  }) =>
      TaskPeriod(
        id: id,
        taskId: taskId,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        note: note ?? this.note,
        createdAt: createdAt,
      );
}
