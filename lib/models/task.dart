class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final bool archived;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.archived = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'archived': archived ? 1 : 0,
      };

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
        archived: (m['archived'] as int) == 1,
      );

  Task copyWith({
    String? title,
    String? description,
    bool? archived,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        createdAt: createdAt,
        archived: archived ?? this.archived,
      );
}
