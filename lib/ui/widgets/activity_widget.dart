import 'package:flutter/material.dart';
import 'package:time_tracker/models/activity.dart';

class ActivityWidget extends StatelessWidget {
  final Activity activity;
  final Duration timerDuration;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final double percentage;
  final bool isSelected;

  const ActivityWidget({
    super.key,
    required this.activity,
    required this.timerDuration,
    required this.onSelect,
    required this.onDelete,
    required this.percentage,
    this.isSelected = false,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? activity.color.withOpacity(0.5) : activity.color,
          borderRadius: BorderRadius.circular(8.0),
          border: isSelected
              ? Border.all(
                  color: Colors.black,
                  width: 2.0) // Жирный бордер для выбранной активности
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(activity.name),
            const Spacer(),
            Text('${percentage.toStringAsFixed(2)}%'),
            Text(_formatDuration(timerDuration)),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
}
