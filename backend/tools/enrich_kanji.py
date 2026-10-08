from __future__ import annotations

"""One-off/resumable OpenAI enrichment of the shared kanji dictionary."""

import argparse
import json
import os
import shutil
import time
from datetime import datetime
from pathlib import Path

from openai import OpenAI

from app.kanji_store import is_kanji


def save_atomic(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix('.json.tmp')
    with temp.open('w', encoding='utf-8') as file:
        json.dump(data, file, ensure_ascii=False, indent=2, sort_keys=True)
        file.write('\n')
    temp.replace(path)


def normalize(glyph: str, item: object) -> dict | None:
    if not isinstance(item, dict):
        return None
    meaning = str(item.get('meaning_ko') or '').strip()[:100]
    if not meaning:
        return None

    def readings(key: str) -> list[str]:
        raw = item.get(key)
        if not isinstance(raw, list):
            return []
        unique: list[str] = []
        for value in raw:
            reading = str(value).strip()[:35]
            if reading and reading not in unique:
                unique.append(reading)
        return unique[:12]

    return {
        'meaning_ko': meaning,
        'onyomi': readings('onyomi'),
        'kunyomi': readings('kunyomi'),
    }


def ask_batch(client: OpenAI, model: str, glyphs: list[str]) -> dict[str, dict]:
    instructions = (
        '너는 일본어 한자 사전 데이터 작성자다. 한국어 학습자를 위한 정확한 정보만 작성한다. '
        '응답은 설명 없이 하나의 JSON 객체로 출력한다. 루트 키는 각각의 한자 한 글자이며, '
        '값은 {"meaning_ko":"한자 뜻과 한국식 음(예: 경계할 경)",'
        '"onyomi":["ケイ"],"kunyomi":["いまし.める"]} 형식이다. '
        '음독/훈독은 일본어 가타카나/히라가나로 적고, 훈독의 오쿠리가나는 점(.)으로 구분한다. '
        '널리 쓰이는 대표 읽기만 넣어라. 실제로 없는 음독이나 훈독을 지어내지 말고 '
        '해당 읽기가 없으면 빈 배열로 출력한다. JLPT 등급, 관련 단어, 설명은 포함하지 않는다. '
        '요청한 글자는 정확히 한 번씩만 반환한다.'
    )
    response = client.responses.create(
        model=model,
        instructions=instructions,
        input='다음 일본 한자를 글자별로 분석해 줘: ' + ' '.join(glyphs),
        max_output_tokens=6000,
    )
    text = (response.output_text or '').strip()
    if text.startswith('```'):
        text = text.split('\n', 1)[-1].rsplit('```', 1)[0].strip()
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError('model response is not a JSON object')
    result: dict[str, dict] = {}
    for glyph in glyphs:
        normalized = normalize(glyph, data.get(glyph))
        if normalized is not None:
            result[glyph] = normalized
    if not result:
        raise ValueError('model response contains no valid kanji entries')
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description='Enrich unique kanji once; resume via kanji.json')
    parser.add_argument('--words', default=os.getenv('WORDS_JSON_PATH', '/app/data/words.json'))
    parser.add_argument('--output', default=os.getenv('KANJI_JSON_PATH', '/app/data/kanji.json'))
    parser.add_argument('--model', default=os.getenv('KANJI_OPENAI_MODEL') or os.getenv('OPENAI_MODEL') or 'gpt-5-mini')
    parser.add_argument('--batch-size', type=int, default=16)
    parser.add_argument('--limit', type=int, default=0, help='Process at most this many new glyphs (0 = all)')
    parser.add_argument('--delay', type=float, default=0.4)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    if not 1 <= args.batch_size <= 40:
        parser.error('--batch-size must be between 1 and 40')

    with Path(args.words).open('r', encoding='utf-8') as file:
        words = json.load(file)
    if not isinstance(words, list):
        raise ValueError('words.json must be a list')
    glyphs = sorted({
        char
        for word in words
        for char in str(word.get('word') or '')
        if is_kanji(char)
    })

    output = Path(args.output)
    if output.exists():
        with output.open('r', encoding='utf-8') as file:
            cache = json.load(file)
        if not isinstance(cache, dict):
            raise ValueError('kanji.json must be a mapping')
    else:
        cache = {}
    todo = [glyph for glyph in glyphs if glyph not in cache]
    if args.limit > 0:
        todo = todo[:args.limit]
    print(json.dumps({
        'word_count': len(words),
        'unique_kanji': len(glyphs),
        'already_cached': len(glyphs) - len([glyph for glyph in glyphs if glyph not in cache]),
        'to_process': len(todo),
        'model': args.model,
    }, ensure_ascii=False), flush=True)
    if args.dry_run or not todo:
        return

    if not os.getenv('OPENAI_API_KEY', '').strip():
        raise RuntimeError('OPENAI_API_KEY is not configured')
    if output.exists():
        stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        backup = output.with_name(f'kanji.before-enrichment.{stamp}.json')
        shutil.copy2(output, backup)
        print('backup=' + str(backup), flush=True)

    client = OpenAI(timeout=120, max_retries=2)
    for start in range(0, len(todo), args.batch_size):
        batch = todo[start:start + args.batch_size]
        for attempt in range(3):
            try:
                enriched = ask_batch(client, args.model, batch)
                break
            except Exception as error:
                if attempt == 2:
                    raise RuntimeError(
                        f'Batch starting at index {start} failed; saved batches are safe to resume'
                    ) from error
                wait = 2 ** (attempt + 1)
                print(f'batch retry {attempt + 1}, wait={wait}s, reason={type(error).__name__}', flush=True)
                time.sleep(wait)
        cache.update(enriched)
        save_atomic(output, cache)
        print(f'progress={min(start + len(batch), len(todo))}/{len(todo)} '
              f'new={len(enriched)} cached={len(cache)}', flush=True)
        if args.delay > 0:
            time.sleep(args.delay)


if __name__ == '__main__':
    main()
