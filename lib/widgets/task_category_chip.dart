import 'package:flutter/material.dart';

import '../models/task_category.dart';

class TaskCategoryChip extends StatelessWidget {
  const TaskCategoryChip({
    super.key,
    required this.category,
    this.small = false,
  });
  final TaskCategory category;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(small ? 8 : 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon,
              size: small ? 10 : 14, color: category.color),
          SizedBox(width: small ? 4 : 6),
          Text(
            category.name,
            style: TextStyle(
              color: category.color,
              fontWeight: FontWeight.w600,
              fontSize: small ? 10 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
