DateTime readDateTime(Map<String, dynamic> map, String key) {
  return DateTime.parse(map[key] as String);
}

DateTime? readNullableDateTime(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  return DateTime.parse(value as String);
}

String writeDateTime(DateTime value) => value.toIso8601String();

String? writeNullableDateTime(DateTime? value) => value?.toIso8601String();
