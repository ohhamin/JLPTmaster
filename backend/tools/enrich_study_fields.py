from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime
from pathlib import Path

from pykakasi import kakasi


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


def enrich(words: list[dict]) -> tuple[list[dict], dict[str, int]]:
    to_hiragana = _reading_converter()

    surfaces: dict[str, list[dict]] = {}
    for word in words:
        candidates = [word.get('word', '')]
        other_forms = word.get('other_forms')
        if isinstance(other_forms, list):
            candidates.extend(str(item) for item in other_forms if item)
        for surface in candidates:
            surface = str(surface).strip()
            if not surface or _is_single_kana(surface):
                continue
            surfaces.setdefault(surface, []).append(word)

    ordered_surfaces = sorted(surfaces, key=len, reverse=True)
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
        word['example_reading'] = str(word.get('example_reading') or to_hiragana(example_ja)).strip()
        if word['example_reading']:
            stats['readings'] += 1
        word['part_of_speech'] = str(word.get('part_of_speech') or _pos_label(word.get('pos'))).strip()

        related: list[dict] = []
        seen_ids: set[str] = set()
        current_id = str(word.get('id', ''))
        if example_ja:
            for surface in ordered_surfaces:
                if surface not in example_ja:
                    continue
                for candidate in surfaces[surface]:
                    candidate_id = str(candidate.get('id', ''))
                    if not candidate_id or candidate_id == current_id or candidate_id in seen_ids:
                        continue
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
