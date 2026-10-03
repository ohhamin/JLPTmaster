class Word {
  const Word({
    required this.id,
    required this.word,
    required this.reading,
    required this.meaningKo,
    required this.level,
    this.exampleJa = '',
    this.exampleKo = '',
    this.tags = const [],
    this.favorite = false,
    this.correctCount = 0,
    this.wrongCount = 0,
  });

  final String id;
  final String word;
  final String reading;
  final String meaningKo;
  final String level;
  final String exampleJa;
  final String exampleKo;
  final List<String> tags;
  final bool favorite;
  final int correctCount;
  final int wrongCount;

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        id: json['id'] as String,
        word: json['word'] as String,
        reading: json['reading'] as String? ?? '',
        meaningKo: json['meaning_ko'] as String? ?? '',
        level: json['level'] as String? ?? 'N5',
        exampleJa: json['example_ja'] as String? ?? '',
        exampleKo: json['example_ko'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
        favorite: json['favorite'] as bool? ?? false,
        correctCount: json['correct_count'] as int? ?? 0,
        wrongCount: json['wrong_count'] as int? ?? 0,
      );
}
