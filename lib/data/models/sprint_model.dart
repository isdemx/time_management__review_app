import 'dart:convert';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/entities/time_line_event.dart';
import 'package:uuid/uuid.dart';

class SprintModel extends Sprint {
  SprintModel({
    String? id,
    required DateTime startTime,
    DateTime? endTime,
    bool isActive = true,
    List<TimeLineEvent>? timeLine,
  }) : super(
          id: id ?? const Uuid().v4(),
          startTime: startTime,
          endTime: endTime,
          isActive: isActive,
          timeLine: timeLine ?? [],
        );

  factory SprintModel.fromJson(Map<String, dynamic> json) {
    var timeLineJson = json['timeline'] != null
        ? jsonDecode(json['timeline']) as List
        : [];
    List<TimeLineEvent> timeLine = timeLineJson
        .map((timeLineEventJson) => TimeLineEvent.fromJson(timeLineEventJson))
        .toList();

    return SprintModel(
      id: json['id'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      isActive: json['isActive'] == 1,
      timeLine: timeLine,
    );
  }

  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> timeLineJson = timeLine
        .map((timeLineEvent) => timeLineEvent.toJson())
        .toList();

    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'timeline': jsonEncode(timeLineJson),
    };
  }
}
