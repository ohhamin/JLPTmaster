import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jlptmaster/src/widgets/copy_text_button.dart';
import 'package:jlptmaster/src/widgets/kanji_section.dart';
import 'package:jlptmaster/src/models/study_summary.dart';
import 'package:jlptmaster/src/models/word.dart';

void main() {
  testWidgets('copy button copies Japanese text exactly', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CopyTextButton(text: '勉強します。', label: '예문')),
    ));
    await tester.tap(find.byTooltip('예문 복사'));
    await tester.pump();
    expect(copied, '勉強します。');
  });

  testWidgets('kanji taps play onyomi while copy does not play', (tester) async {
    final spoken = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KanjiSection(
          kanji: const [
            KanjiInfo(
              character: '警',
              meaningKo: '경계할 경',
              onyomi: ['ケイ'],
              kunyomi: ['いまし.める'],
            ),
          ],
          onSpeak: spoken.add,
        ),
      ),
    ));
    await tester.tap(find.text('警'));
    await tester.pump();
    expect(spoken, ['ケイ']);
    await tester.tap(find.byTooltip('한자 복사'));
    await tester.pump();
    expect(spoken, ['ケイ']);
  });

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
