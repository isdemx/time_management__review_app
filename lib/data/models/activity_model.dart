
import 'package:time_tracker/domain/entities/activity.dart';

class ActivityModel extends Activity {
  ActivityModel({
    required String name,
    required String color,
    required String icon,
    // required String group,
    // required String type,
    required bool isNotified,
  }) : super(
          name: name,
          color: color,
          icon: icon,
          // group: group,
          // type: type,
          isNotified: isNotified,
        );

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      name: json['name'],
      color: json['color'],
      icon: json['icon'],
      // group: json['group'],
      // type: json['type'],
      isNotified: json['isNotified'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color,
      'icon': icon,
      // 'group': group,
      // 'type': type,
      'isNotified': isNotified,
    };
  }
}
