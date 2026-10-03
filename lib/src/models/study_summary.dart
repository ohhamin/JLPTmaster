class LevelSummary {
  const LevelSummary({
    required this.level,
    required this.total,
    required this.known,
    required this.favorites,
    required this.chapters,
  });

  final String level;
  final int total;
  final int known;
  final int favorites;
  final int chapters;

  double get progress => total == 0 ? 0 : known / total;

  factory LevelSummary.fromJson(Map<String, dynamic> json) => LevelSummary(
        level: json['level'] as String? ?? 'N5',
        total: (json['total'] as num?)?.toInt() ?? 0,
        known: (json['known'] as num?)?.toInt() ?? 0,
        favorites: (json['favorites'] as num?)?.toInt() ?? 0,
        chapters: (json['chapters'] as num?)?.toInt() ?? 0,
      );
}

class ChapterSummary {
  const ChapterSummary({
    required this.level,
    required this.chapter,
    required this.total,
    required this.known,
  });

  final String level;
  final int chapter;
  final int total;
  final int known;

  double get progress => total == 0 ? 0 : known / total;

  factory ChapterSummary.fromJson(Map<String, dynamic> json) => ChapterSummary(
        level: json['level'] as String? ?? 'N5',
        chapter: (json['chapter'] as num?)?.toInt() ?? 1,
        total: (json['total'] as num?)?.toInt() ?? 0,
        known: (json['known'] as num?)?.toInt() ?? 0,
      );
}
