import 'package:flutter/material.dart';
import 'package:time_tracker/presentation/utils/time_format_util.dart';

class TimerDisplay extends StatelessWidget {
  final Duration duration;
  final VoidCallback onPause;
  final VoidCallback onReset;

  const TimerDisplay({
    Key? key,
    required this.duration,
    required this.onPause,
    required this.onReset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(TimeFormatUtil.formatDuration(duration), style: const TextStyle(fontSize: 54.0, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.pause), onPressed: onPause, color: Colors.red),
          IconButton(icon: const Icon(Icons.stop), onPressed: onReset, color: Colors.orange),
        ],
      ),
    );
  }
}
