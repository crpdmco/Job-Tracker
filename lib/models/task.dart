class Task {
  final String id;
  final String title;
  final String? description;
  final String? categoryId;
  final DateTime createdAt;
  final bool archived;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.categoryId,
    required this.createdAt,
    this.archived = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'categoryId': categoryId,
        'createdAt': createdAt.toIso8601String(),
        'archived': archived ? 1 : 0,
      };

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        categoryId: m['categoryId'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
        archived: (m['archived'] as int) == 1,
      );

  Task copyWith({
    String? title,
    String? description,
    String? categoryId,
    bool? archived,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        categoryId: categoryId ?? this.categoryId,
        createdAt: createdAt,
        archived: archived ?? this.archived,
      );
}
