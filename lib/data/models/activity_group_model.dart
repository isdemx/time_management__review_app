import 'package:time_tracker/data/models/activity_model.dart';
import 'package:time_tracker/domain/entities/activity.dart';
import 'package:time_tracker/domain/entities/activity_group.dart';
import 'package:uuid/uuid.dart';

class ActivityGroupModel extends ActivityGroup {
  ActivityGroupModel({
    String? id,
    required String name,
    required List<Activity> activities
  }) : super(
          id: id ?? const Uuid().v4(),
          name: name,
          activities: activities ?? []
        );

  factory ActivityGroupModel.fromJson(Map<String, dynamic> json) {
    return ActivityGroupModel(
      id: json['id'],
      name: json['name'],
       activities: (json['activities'] as List).map((activityJson) => ActivityModel.fromJson(activityJson)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'activities': activities.map((activity) => (activity as ActivityModel).toJson()).toList()
    };
  }
}
