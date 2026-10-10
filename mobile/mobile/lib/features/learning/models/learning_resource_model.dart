enum LearningResourceType { video, article, course }

class LearningResourceModel {
  final String id;
  final String title;
  final String description;
  final String url;
  final LearningResourceType type;
  final String? category;
  final int? durationMinutes;

  const LearningResourceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.type,
    this.category,
    this.durationMinutes,
  });
}
