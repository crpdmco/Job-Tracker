import 'package:flutter/material.dart';

class TaskCategory {
  final String id;
  final String name;
  final int colorValue;
  final String iconName;

  TaskCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    this.iconName = 'work',
  });

  Color get color => Color(colorValue);

  IconData get icon {
    switch (iconName) {
      case 'code':
        return Icons.code;
      case 'design':
        return Icons.palette;
      case 'meeting':
        return Icons.groups;
      case 'bug':
        return Icons.bug_report;
      case 'research':
        return Icons.search;
      case 'writing':
        return Icons.edit_note;
      case 'admin':
        return Icons.folder;
      default:
        return Icons.work_outline;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'iconName': iconName,
      };

  factory TaskCategory.fromMap(Map<String, dynamic> m) => TaskCategory(
        id: m['id'] as String,
        name: m['name'] as String,
        colorValue: m['colorValue'] as int,
        iconName: (m['iconName'] as String?) ?? 'work',
      );

  TaskCategory copyWith({String? name, int? colorValue, String? iconName}) =>
      TaskCategory(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        iconName: iconName ?? this.iconName,
      );
}
