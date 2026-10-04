from __future__ import annotations

import json
import os
import threading
from pathlib import Path

_GLOBAL_STATE_FIELDS = {'favorite', 'correct_count', 'wrong_count', 'updated_at'}


class JsonWordStore:
    def __init__(self) -> None:
        words_path = os.getenv('WORDS_JSON_PATH', '/app/data/words.json')
        progress_path = os.getenv('PROGRESS_JSON_PATH', '/app/data/progress.json')
        self.path = Path(words_path)
        self.progress_path = Path(progress_path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.progress_path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()
        self._flush_timer: threading.Timer | None = None

        if not self.path.exists():
            self._write_json(self.path, [])
        if not self.progress_path.exists():
            self._write_json(self.progress_path, {})

        self._words = self._read_words_file()
        self._rebuild_indexes()
        raw_progress = self._read_progress_file()
        self._word_states, self._chapter_known = self._normalize_progress(raw_progress)

    @staticmethod
    def _write_json(path: Path, value: object) -> None:
        temp_path = path.with_suffix(path.suffix + '.tmp')
        with temp_path.open('w', encoding='utf-8') as file:
            json.dump(value, file, ensure_ascii=False, separators=(',', ':'))
            file.write('\n')
        temp_path.replace(path)

    def _read_words_file(self) -> list[dict]:
        with self.path.open('r', encoding='utf-8') as file:
            data = json.load(file)
        if not isinstance(data, list):
            raise ValueError('words.json must contain a JSON array')
        return data

    def _read_progress_file(self) -> dict:
        with self.progress_path.open('r', encoding='utf-8') as file:
            data = json.load(file)
        if not isinstance(data, dict):
            raise ValueError('progress.json must contain a JSON object')
        return data

    def _normalize_progress(self, data: dict) -> tuple[dict[str, dict], dict[str, bool]]:
        # v2 shape: global per-word state + chapter-scoped known state.
        if 'word_states' in data or 'chapter_known' in data:
            word_states = data.get('word_states') or {}
            chapter_known = data.get('chapter_known') or {}
            if not isinstance(word_states, dict) or not isinstance(chapter_known, dict):
                raise ValueError('invalid progress.json v2 structure')
            return (
                {str(key): dict(value) for key, value in word_states.items() if isinstance(value, dict)},
                {str(key): bool(value) for key, value in chapter_known.items() if bool(value)},
            )

        # Migrate the previous flat structure. Existing `known` is preserved only
        # in the word's original chapter so cumulative chapters start independently.
        word_states: dict[str, dict] = {}
        chapter_known: dict[str, bool] = {}
        for word_id, state in data.items():
            if not isinstance(state, dict):
                continue
            global_state = {
                key: value
                for key, value in state.items()
                if key in _GLOBAL_STATE_FIELDS
            }
            if global_state:
                word_states[str(word_id)] = global_state
            if bool(state.get('known', False)):
                base = self._word_index.get(str(word_id))
                if base is not None:
                    level = str(base.get('level', 'N5'))
                    chapter = int(base.get('chapter') or 1)
                    chapter_known[self._known_key(str(word_id), level, chapter)] = True
        return word_states, chapter_known

    def _rebuild_indexes(self) -> None:
        self._word_index = {
            str(word.get('id')): word
            for word in self._words
            if word.get('id') is not None
        }
        self._surface_index: dict[str, dict] = {}
        self._surface_word_ids: dict[str, list[str]] = {}
        for word in self._words:
            surface = str(word.get('word', ''))
            if not surface:
                continue
            if surface not in self._surface_index:
                self._surface_index[surface] = word
            word_id = str(word.get('id', ''))
            if word_id:
                self._surface_word_ids.setdefault(surface, []).append(word_id)

    @staticmethod
    def _known_key(word_id: str, level: str, chapter: int) -> str:
        return f'{level}:{chapter}:{word_id}'

    def _schedule_progress_flush(self) -> None:
        if self._flush_timer is not None:
            self._flush_timer.cancel()
        timer = threading.Timer(0.18, self.flush_progress)
        timer.daemon = True
        self._flush_timer = timer
        timer.start()

    def flush_progress(self) -> None:
        with self._lock:
            snapshot = {
                'word_states': {
                    word_id: dict(state)
                    for word_id, state in self._word_states.items()
                },
                'chapter_known': dict(self._chapter_known),
            }
            self._write_json(self.progress_path, snapshot)
            self._flush_timer = None

    def _enrich_related(self, word: dict) -> dict:
        merged = dict(word)
        related_items = merged.get('example_words') or []
        if not isinstance(related_items, list):
            return merged

        enriched: list[dict] = []
        for item in related_items:
            if not isinstance(item, dict):
                continue
            result = dict(item)
            related_id = result.get('id')
            base = self._word_index.get(str(related_id)) if related_id else None
            if base is None:
                base = self._surface_index.get(str(result.get('word', '')))
            if base is not None:
                result.setdefault('example_ja', base.get('example_ja', ''))
                result.setdefault('example_ko', base.get('example_ko', ''))
            enriched.append(result)
        merged['example_words'] = enriched
        return merged

    def _merge_state(self, word: dict, known_chapter: int | None = None) -> dict:
        word_id = str(word.get('id', ''))
        state = self._word_states.get(word_id, {})
        merged = dict(word)
        for field in _GLOBAL_STATE_FIELDS:
            if field in state:
                merged[field] = state[field]
        merged.setdefault('favorite', False)
        merged.setdefault('correct_count', 0)
        merged.setdefault('wrong_count', 0)

        chapter = known_chapter if known_chapter is not None else int(word.get('chapter') or 1)
        level = str(word.get('level', 'N5'))
        merged['known'] = bool(self._chapter_known.get(self._known_key(word_id, level, chapter), False))
        merged['study_chapter'] = chapter
        return self._enrich_related(merged)

    def list_words(self, known_chapter: int | None = None) -> list[dict]:
        with self._lock:
            return [self._merge_state(word, known_chapter) for word in self._words]

    def get_word(self, word_id: str, known_chapter: int | None = None) -> dict | None:
        with self._lock:
            base = self._word_index.get(word_id)
            return None if base is None else self._merge_state(base, known_chapter)

    def is_known(self, word_id: str, chapter: int) -> bool:
        with self._lock:
            base = self._word_index.get(word_id)
            if base is None:
                return False
            level = str(base.get('level', 'N5'))
            return bool(self._chapter_known.get(self._known_key(word_id, level, chapter), False))

    def update_states(self, updates: list[dict]) -> list[dict]:
        with self._lock:
            updated_words: list[dict] = []
            for update in updates:
                word_id = str(update.get('word_id', ''))
                base = self._word_index.get(word_id)
                if base is None:
                    raise KeyError(word_id)

                state = dict(self._word_states.get(word_id, {}))
                for field in _GLOBAL_STATE_FIELDS:
                    if field in update:
                        state[field] = update[field]
                if state:
                    self._word_states[word_id] = state

                # Favorites are a property of the lexical item, not a study chapter.
                if 'favorite' in update:
                    surface = str(base.get('word', ''))
                    for sibling_id in self._surface_word_ids.get(surface, [word_id]):
                        sibling_state = dict(self._word_states.get(sibling_id, {}))
                        sibling_state['favorite'] = bool(update['favorite'])
                        if 'updated_at' in update:
                            sibling_state['updated_at'] = update['updated_at']
                        self._word_states[sibling_id] = sibling_state

                chapter = int(update.get('chapter') or base.get('chapter') or 1)
                if 'known' in update:
                    level = str(base.get('level', 'N5'))
                    key = self._known_key(word_id, level, chapter)
                    if bool(update['known']):
                        self._chapter_known[key] = True
                    else:
                        self._chapter_known.pop(key, None)

                updated_words.append(self._merge_state(base, chapter))

            self._schedule_progress_flush()
            return updated_words

    def create_word(self, word: dict) -> None:
        with self._lock:
            base = {
                key: value
                for key, value in word.items()
                if key not in _GLOBAL_STATE_FIELDS and key != 'known'
            }
            self._words.append(base)
            self._rebuild_indexes()
            self._write_json(self.path, self._words)

            word_id = str(word['id'])
            state = {
                key: word[key]
                for key in _GLOBAL_STATE_FIELDS
                if key in word
            }
            if state:
                self._word_states[word_id] = state
            if bool(word.get('known', False)):
                level = str(word.get('level', 'N5'))
                chapter = int(word.get('chapter') or 1)
                self._chapter_known[self._known_key(word_id, level, chapter)] = True
            self._schedule_progress_flush()

    def replace_word(self, word_id: str, updated: dict) -> None:
        with self._lock:
            base = self._word_index.get(word_id)
            if base is None:
                raise KeyError(word_id)

            base_updated = {
                key: value
                for key, value in updated.items()
                if key not in _GLOBAL_STATE_FIELDS and key not in {'known', 'study_chapter'}
            }
            if base_updated != base:
                index = self._words.index(base)
                self._words[index] = base_updated
                self._rebuild_indexes()
                self._write_json(self.path, self._words)

            state_update = {'word_id': word_id}
            state_update.update({
                key: updated[key]
                for key in _GLOBAL_STATE_FIELDS
                if key in updated
            })
            if 'known' in updated:
                state_update['known'] = updated['known']
                state_update['chapter'] = int(updated.get('study_chapter') or updated.get('chapter') or 1)
            self.update_states([state_update])

    def delete_word(self, word_id: str) -> bool:
        with self._lock:
            base = self._word_index.get(word_id)
            if base is None:
                return False
            self._words.remove(base)
            self._rebuild_indexes()
            self._write_json(self.path, self._words)
            self._word_states.pop(word_id, None)
            suffix = f':{word_id}'
            for key in [key for key in self._chapter_known if key.endswith(suffix)]:
                self._chapter_known.pop(key, None)
            self._schedule_progress_flush()
            return True
