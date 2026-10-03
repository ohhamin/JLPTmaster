import 'package:flutter_test/flutter_test.dart';
import 'package:jlptmaster/src/models/study_summary.dart';
import 'package:jlptmaster/src/models/word.dart';

void main() {
  test('Word parses study and example metadata', () {
    final word = Word.fromJson({
      'id': 'sample',
      'word': '勉強',
      'reading': 'べんきょう',
      'meaning_ko': '공부',
      'level': 'N5',
      'chapter': 2,
      'example_reading': 'まいにち、にほんごをべんきょうします。',
      'favorite': true,
      'known': true,
      'example_words': [
        {
          'word': '毎日',
          'reading': 'まいにち',
          'meaning_ko': '매일',
          'level': 'N5',
        },
      ],
    });

    expect(word.word, '勉強');
    expect(word.reading, 'べんきょう');
    expect(word.meaningKo, '공부');
    expect(word.level, 'N5');
    expect(word.chapter, 2);
    expect(word.favorite, isTrue);
    expect(word.known, isTrue);
    expect(word.exampleWords.single.word, '毎日');
  });

  test('Chapter progress is derived from known and total', () {
    final chapter = ChapterSummary.fromJson({
      'level': 'N5',
      'chapter': 1,
      'known': 10,
      'total': 50,
    });

    expect(chapter.progress, 0.2);
  });
}
