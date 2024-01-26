import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final Duration duration;
  final bool isTimerRunning;
  final VoidCallback onStop;
  final VoidCallback onReset;

  const TimerDisplay({
    super.key,
    required this.duration,
    required this.isTimerRunning,
    required this.onStop,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$hours:$minutes:$seconds',
            style: const TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isTimerRunning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: onStop,
              color: Colors.red,
            ),
          if (!isTimerRunning)
            IconButton(
              icon: const Icon(Icons.reset_tv),
              onPressed: onReset,
              color: Colors.orange,
            ),
        ],
      ),
    );
  }
}
