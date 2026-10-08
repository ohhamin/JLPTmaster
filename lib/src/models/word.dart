class RelatedWord {
  const RelatedWord({
    this.id,
    required this.word,
    this.reading = '',
    this.meaningKo = '',
    this.level,
    this.exampleJa = '',
    this.exampleKo = '',
  });

  final String? id;
  final String word;
  final String reading;
  final String meaningKo;
  final String? level;
  final String exampleJa;
  final String exampleKo;

  factory RelatedWord.fromJson(Map<String, dynamic> json) => RelatedWord(
        id: json['id'] as String?,
        word: json['word'] as String? ?? '',
        reading: json['reading'] as String? ?? '',
        meaningKo: json['meaning_ko'] as String? ?? '',
        level: json['level'] as String?,
        exampleJa: json['example_ja'] as String? ?? '',
        exampleKo: json['example_ko'] as String? ?? '',
      );
}

class KanjiInfo {
  const KanjiInfo({
    required this.character,
    required this.meaningKo,
    required this.onyomi,
    required this.kunyomi,
  });

  final String character;
  final String meaningKo;
  final List<String> onyomi;
  final List<String> kunyomi;

  factory KanjiInfo.fromJson(Map<String, dynamic> json) => KanjiInfo(
        character: json['character'] as String? ?? '',
        meaningKo: json['meaning_ko'] as String? ?? '',
        onyomi: (json['onyomi'] as List<dynamic>? ?? const []).whereType<String>().toList(),
        kunyomi: (json['kunyomi'] as List<dynamic>? ?? const []).whereType<String>().toList(),
      );
}

class Word {
  const Word({
    required this.id,
    required this.word,
    required this.reading,
    required this.meaningKo,
    required this.level,
    this.chapter = 1,
    this.partOfSpeech = '',
    this.exampleJa = '',
    this.exampleReading = '',
    this.exampleKo = '',
    this.exampleWords = const [],
    this.kanji = const [],
    this.tags = const [],
    this.favorite = false,
    this.known = false,
    this.correctCount = 0,
    this.wrongCount = 0,
  });

  final String id;
  final String word;
  final String reading;
  final String meaningKo;
  final String level;
  final int chapter;
  final String partOfSpeech;
  final String exampleJa;
  final String exampleReading;
  final String exampleKo;
  final List<RelatedWord> exampleWords;
  final List<KanjiInfo> kanji;
  final List<String> tags;
  final bool favorite;
  final bool known;
  final int correctCount;
  final int wrongCount;

  Word copyWith({bool? favorite, bool? known, List<KanjiInfo>? kanji}) => Word(
        id: id,
        word: word,
        reading: reading,
        meaningKo: meaningKo,
        level: level,
        chapter: chapter,
        partOfSpeech: partOfSpeech,
        exampleJa: exampleJa,
        exampleReading: exampleReading,
        exampleKo: exampleKo,
        exampleWords: exampleWords,
        kanji: kanji ?? this.kanji,
        tags: tags,
        favorite: favorite ?? this.favorite,
        known: known ?? this.known,
        correctCount: correctCount,
        wrongCount: wrongCount,
      );

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        id: json['id'] as String,
        word: json['word'] as String,
        reading: json['reading'] as String? ?? '',
        meaningKo: json['meaning_ko'] as String? ?? '',
        level: json['level'] as String? ?? 'N5',
        chapter: (json['chapter'] as num?)?.toInt() ?? 1,
        partOfSpeech: json['part_of_speech'] as String? ?? '',
        exampleJa: json['example_ja'] as String? ?? '',
        exampleReading: json['example_reading'] as String? ?? '',
        exampleKo: json['example_ko'] as String? ?? '',
        exampleWords: (json['example_words'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RelatedWord.fromJson)
            .toList(),
        kanji: (json['kanji'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(KanjiInfo.fromJson)
            .toList(),
        tags: (json['tags'] as List<dynamic>? ?? const []).whereType<String>().toList(),
        favorite: json['favorite'] as bool? ?? false,
        known: json['known'] as bool? ?? false,
        correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
        wrongCount: (json['wrong_count'] as num?)?.toInt() ?? 0,
      );
}
