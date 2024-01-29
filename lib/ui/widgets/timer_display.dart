import 'package:flutter/material.dart';
import 'package:time_tracker/models/common_timer.dart';

class TimerDisplay extends StatefulWidget {
  final CommonTimer commonTimer;

  const TimerDisplay({Key? key, required this.commonTimer}) : super(key: key);

  @override
  _TimerDisplayState createState() => _TimerDisplayState();
}

class _TimerDisplayState extends State<TimerDisplay> {
  Duration _duration = Duration.zero;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    widget.commonTimer.durationStream.listen((timerData) {
      setState(() {
        _duration = timerData.duration;
        _isRunning = timerData.isRunning;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_duration.inHours);
    final minutes = twoDigits(_duration.inMinutes.remainder(60));
    final seconds = twoDigits(_duration.inSeconds.remainder(60));

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
          if (_isRunning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: widget.commonTimer.pause,
              color: Colors.red,
            ),
          if (!_isRunning)
            IconButton(
              icon: const Icon(Icons.reset_tv),
              onPressed: widget.commonTimer.reset,
              color: Colors.orange,
            ),
        ],
      ),
    );
  }
}
