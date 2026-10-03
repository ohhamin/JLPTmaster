import 'package:flutter_test/flutter_test.dart';
import 'package:jlptmaster/src/models/word.dart';

void main() {
  test('Word parses JSON payload', () {
    final word = Word.fromJson({
      'id': 'sample',
      'word': '勉強',
      'reading': 'べんきょう',
      'meaning_ko': '공부',
      'level': 'N5',
    });

    expect(word.word, '勉強');
    expect(word.reading, 'べんきょう');
    expect(word.meaningKo, '공부');
    expect(word.level, 'N5');
  });
}
