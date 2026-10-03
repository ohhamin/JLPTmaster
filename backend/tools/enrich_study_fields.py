from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime
from pathlib import Path

from fugashi import Tagger
from pykakasi import kakasi

_LEVEL_RANK = {'N5': 0, 'N4': 1, 'N3': 2, 'N2': 3, 'N1': 4}


def _is_single_kana(text: str) -> bool:
    if len(text) != 1:
        return False
    code = ord(text)
    return 0x3040 <= code <= 0x30FF


def _pos_label(pos: object) -> str:
    values = [str(item) for item in pos] if isinstance(pos, list) else []
    if not values:
        return ''
    labels: list[str] = []
    for value in values:
        if value == 'n' or value.startswith('n-'):
            label = '명사'
        elif value == 'pn':
            label = '대명사'
        elif value == 'adv' or value.startswith('adv-'):
            label = '부사'
        elif value == 'adj-i' or value.startswith('adj-ix'):
            label = 'い형용사'
        elif value.startswith('adj-na'):
            label = 'な형용사'
        elif value.startswith('v1') or value.startswith('v5') or value.startswith('vk') or value.startswith('vs'):
            label = '동사'
        elif value == 'prt':
            label = '조사'
        elif value == 'exp':
            label = '표현'
        else:
            continue
        if label not in labels:
            labels.append(label)
    return ' · '.join(labels) if labels else ' / '.join(values)


def _reading_converter():
    converter = kakasi()

    def to_hiragana(text: str) -> str:
        if not text:
            return ''
        return ''.join(part.get('hira', part.get('orig', '')) for part in converter.convert(text))

    return to_hiragana


def _token_keys(token: object) -> list[str]:
    keys: list[str] = []
    surface = str(getattr(token, 'surface', '') or '').strip()
    if surface:
        keys.append(surface)
    feature = getattr(token, 'feature', None)
    if feature is not None:
        for name in ('lemma', 'orthBase'):
            value = str(getattr(feature, name, '') or '').strip()
            if value and value != '*' and value not in keys:
                keys.append(value)
    return keys


def _token_reading(token: object, to_hiragana) -> str:
    feature = getattr(token, 'feature', None)
    if feature is None:
        return ''
    for name in ('kana', 'kanaBase', 'pron', 'pronBase'):
        value = str(getattr(feature, name, '') or '').strip()
        if value and value != '*':
            return to_hiragana(value)
    return ''


def enrich(words: list[dict]) -> tuple[list[dict], dict[str, int]]:
    to_hiragana = _reading_converter()
    tagger = Tagger()

    lexicon: dict[str, list[dict]] = {}
    for word in words:
        candidates = [word.get('word', '')]
        other_forms = word.get('other_forms')
        if isinstance(other_forms, list):
            candidates.extend(str(item) for item in other_forms if item)
        for surface in candidates:
            surface = str(surface).strip()
            if not surface or _is_single_kana(surface):
                continue
            lexicon.setdefault(surface, []).append(word)

    stats = {'total': len(words), 'examples': 0, 'readings': 0, 'related_links': 0}

    for word in words:
        examples = word.get('examples')
        example = examples[0] if isinstance(examples, list) and examples and isinstance(examples[0], dict) else {}
        example_ja = str(word.get('example_ja') or example.get('ja') or '').strip()
        example_ko = str(word.get('example_ko') or example.get('ko') or '').strip()
        if example_ja:
            stats['examples'] += 1

        word['example_ja'] = example_ja
        word['example_ko'] = example_ko
        # Keep the written hiragana reading stable even when token pronunciation differs
        # (for example は as a particle is kept as は rather than わ).
        word['example_reading'] = to_hiragana(example_ja).strip()
        if word['example_reading']:
            stats['readings'] += 1
        word['part_of_speech'] = str(word.get('part_of_speech') or _pos_label(word.get('pos'))).strip()

        related: list[dict] = []
        seen_ids: set[str] = set()
        current_id = str(word.get('id', ''))
        if example_ja:
            for token in tagger(example_ja):
                token_candidates: dict[str, dict] = {}
                for key in _token_keys(token):
                    for candidate in lexicon.get(key, []):
                        candidate_id = str(candidate.get('id', ''))
                        if not candidate_id or candidate_id == current_id or candidate_id in seen_ids:
                            continue
                        token_candidates[candidate_id] = candidate
                if not token_candidates:
                    continue

                token_reading = _token_reading(token, to_hiragana)
                ranked = sorted(
                    token_candidates.values(),
                    key=lambda candidate: (
                        0
                        if token_reading
                        and to_hiragana(str(candidate.get('reading') or candidate.get('hiragana') or '')) == token_reading
                        else 1,
                        _LEVEL_RANK.get(str(candidate.get('level', '')), 99),
                        str(candidate.get('word', '')),
                    ),
                )
                candidate = ranked[0]
                candidate_id = str(candidate.get('id', ''))
                seen_ids.add(candidate_id)
                related.append(
                    {
                        'id': candidate_id,
                        'word': str(candidate.get('word', '')),
                        'reading': str(candidate.get('reading') or candidate.get('hiragana') or ''),
                        'meaning_ko': str(candidate.get('meaning_ko') or ''),
                        'level': candidate.get('level'),
                    }
                )
                if len(related) >= 12:
                    break

        word['example_words'] = related
        stats['related_links'] += len(related)

    return words, stats


def main() -> None:
    parser = argparse.ArgumentParser(description='Add study-screen fields to JLPT words JSON.')
    parser.add_argument('--path', default='/app/data/words.json', help='Path to words.json')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    path = Path(args.path)
    with path.open('r', encoding='utf-8') as file:
        data = json.load(file)
    if not isinstance(data, list):
        raise ValueError('words.json must contain a JSON array')

    enriched, stats = enrich(data)
    print(json.dumps(stats, ensure_ascii=False))
    if args.dry_run:
        return

    stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    backup = path.with_name(f'{path.stem}.before-study-fields.{stamp}{path.suffix}')
    shutil.copy2(path, backup)
    temp = path.with_suffix('.tmp')
    with temp.open('w', encoding='utf-8') as file:
        json.dump(enriched, file, ensure_ascii=False, indent=2)
        file.write('\n')
    temp.replace(path)
    print(f'backup={backup}')


if __name__ == '__main__':
    main()
