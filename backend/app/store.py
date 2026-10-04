from __future__ import annotations

import json
import os
import threading
from pathlib import Path

_STATE_FIELDS = {'favorite', 'known', 'correct_count', 'wrong_count', 'updated_at'}


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
        self._progress = self._read_progress_file()
        self._rebuild_indexes()

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

    def _read_progress_file(self) -> dict[str, dict]:
        with self.progress_path.open('r', encoding='utf-8') as file:
            data = json.load(file)
        if not isinstance(data, dict):
            raise ValueError('progress.json must contain a JSON object')
        return data

    def _rebuild_indexes(self) -> None:
        self._word_index = {
            str(word.get('id')): word
            for word in self._words
            if word.get('id') is not None
        }
        self._surface_index: dict[str, dict] = {}
        for word in self._words:
            surface = str(word.get('word', ''))
            if surface and surface not in self._surface_index:
                self._surface_index[surface] = word

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
                word_id: dict(state)
                for word_id, state in self._progress.items()
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

    def _merge_state(self, word: dict) -> dict:
        word_id = str(word.get('id', ''))
        state = self._progress.get(word_id, {})
        merged = dict(word)
        for field in _STATE_FIELDS:
            if field in state:
                merged[field] = state[field]
        merged.setdefault('favorite', False)
        merged.setdefault('known', False)
        merged.setdefault('correct_count', 0)
        merged.setdefault('wrong_count', 0)
        return self._enrich_related(merged)

    def list_words(self) -> list[dict]:
        with self._lock:
            return [self._merge_state(word) for word in self._words]

    def get_word(self, word_id: str) -> dict | None:
        with self._lock:
            base = self._word_index.get(word_id)
            return None if base is None else self._merge_state(base)

    def update_states(self, updates: list[dict]) -> list[dict]:
        with self._lock:
            updated_words: list[dict] = []
            for update in updates:
                word_id = str(update.get('word_id', ''))
                base = self._word_index.get(word_id)
                if base is None:
                    raise KeyError(word_id)
                current_state = dict(self._progress.get(word_id, {}))
                for field in _STATE_FIELDS:
                    if field in update:
                        current_state[field] = update[field]
                self._progress[word_id] = current_state
                updated_words.append(self._merge_state(base))
            self._schedule_progress_flush()
            return updated_words

    def create_word(self, word: dict) -> None:
        with self._lock:
            base = {key: value for key, value in word.items() if key not in _STATE_FIELDS}
            self._words.append(base)
            self._rebuild_indexes()
            self._write_json(self.path, self._words)

            word_id = str(word['id'])
            self._progress[word_id] = {
                key: word[key]
                for key in _STATE_FIELDS
                if key in word
            }
            self._schedule_progress_flush()

    def replace_word(self, word_id: str, updated: dict) -> None:
        with self._lock:
            base = self._word_index.get(word_id)
            if base is None:
                raise KeyError(word_id)

            base_updated = {
                key: value
                for key, value in updated.items()
                if key not in _STATE_FIELDS
            }
            if base_updated != base:
                index = self._words.index(base)
                self._words[index] = base_updated
                self._rebuild_indexes()
                self._write_json(self.path, self._words)

            state_update = {'word_id': word_id}
            state_update.update({
                key: updated[key]
                for key in _STATE_FIELDS
                if key in updated
            })
            self.update_states([state_update])

    def delete_word(self, word_id: str) -> bool:
        with self._lock:
            base = self._word_index.get(word_id)
            if base is None:
                return False
            self._words.remove(base)
            self._rebuild_indexes()
            self._write_json(self.path, self._words)
            self._progress.pop(word_id, None)
            self._schedule_progress_flush()
            return True
