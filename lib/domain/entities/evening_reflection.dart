class EveningReflection {
  final String id;
  final String daySessionId;
  final DateTime date;
  final String completionFeeling;
  final String energyLevel;
  final String mood;
  final String comment;
  final DateTime createdAt;

  const EveningReflection({
    required this.id,
    required this.daySessionId,
    required this.date,
    required this.completionFeeling,
    required this.energyLevel,
    required this.mood,
    required this.comment,
    required this.createdAt,
  });
}
