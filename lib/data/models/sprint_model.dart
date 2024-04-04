import 'package:time_tracker/data/models/activity_model.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:uuid/uuid.dart';

class SprintModel extends Sprint {
  SprintModel({
    String? id,
    List<ActivityModel> activities = const [],
    required DateTime startTime,
    DateTime? endTime,
    bool isActive = true,
  }) : super(
          id: id ?? const Uuid().v4(),
          activities: activities,
          startTime: startTime,
          endTime: endTime,
          isActive: isActive,
        );

  factory SprintModel.fromJson(Map<String, dynamic> json) {
    return SprintModel(
      id: json['id'],
      activities: (json['activities'] as List).map((activityJson) => ActivityModel.fromJson(activityJson)).toList(),
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      isActive: json['isActive'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activities': activities.map((activity) => (activity as ActivityModel).toJson()).toList(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isActive': isActive,
    };
  }
}
