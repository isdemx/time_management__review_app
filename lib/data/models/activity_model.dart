import 'package:time_tracker/domain/entities/activity.dart';
import 'package:uuid/uuid.dart';

class ActivityModel extends Activity {
  ActivityModel({
    String? id,
    required String name,
    required String color,
    required String icon,
    String? groupId,
    // required String type,
    required bool isNotified,
  }) : super(
          id: id ?? const Uuid().v4(),
          name: name,
          color: color,
          icon: icon,
          groupId: groupId,
          // type: type,
          isNotified: isNotified,
        );

  factory ActivityModel.fromEntity(Activity activity) {
    return ActivityModel(
      id: activity.id,
      name: activity.name,
      color: activity.color,
      icon: activity.icon,
      groupId: activity.groupId,
      // group: activity.group,
      // type: activity.type,
      isNotified: activity.isNotified,
    );
  }

  Activity toEntity() {
    return Activity(
      id: id,
      name: name,
      color: color,
      icon: icon,
      groupId: groupId,
      // group: group,
      // type: type,
      isNotified: isNotified,
    );
  }

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'],
      name: json['name'],
      color: json['color'],
      icon: json['icon'],
      groupId: json['groupId'],
      // type: json['type'],
      isNotified: json['isNotified'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'groupId': groupId,
      // 'type': type,
      'isNotified': isNotified
          ? 1
          : 0, // SQLite не поддерживает напрямую boolean, поэтому конвертируем в int
    };
  }
}
