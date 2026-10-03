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
        if not self.path.exists():
            self._write_words([])
        if not self.progress_path.exists():
            self._write_progress({})

    def _read_words(self) -> list[dict]:
        with self.path.open('r', encoding='utf-8') as file:
            data = json.load(file)
        if not isinstance(data, list):
            raise ValueError('words.json must contain a JSON array')
        return data

    def _write_words(self, words: list[dict]) -> None:
        temp_path = self.path.with_suffix('.tmp')
        with temp_path.open('w', encoding='utf-8') as file:
            json.dump(words, file, ensure_ascii=False, indent=2)
            file.write('\n')
        temp_path.replace(self.path)

    def _read_progress(self) -> dict[str, dict]:
        with self.progress_path.open('r', encoding='utf-8') as file:
            data = json.load(file)
        if not isinstance(data, dict):
            raise ValueError('progress.json must contain a JSON object')
        return data

    def _write_progress(self, progress: dict[str, dict]) -> None:
        temp_path = self.progress_path.with_suffix('.tmp')
        with temp_path.open('w', encoding='utf-8') as file:
            json.dump(progress, file, ensure_ascii=False, indent=2)
            file.write('\n')
        temp_path.replace(self.progress_path)

    @staticmethod
    def _merge_state(word: dict, progress: dict[str, dict]) -> dict:
        word_id = str(word.get('id', ''))
        state = progress.get(word_id, {})
        merged = dict(word)
        for field in _STATE_FIELDS:
            if field in state:
                merged[field] = state[field]
        merged.setdefault('favorite', False)
        merged.setdefault('known', False)
        merged.setdefault('correct_count', 0)
        merged.setdefault('wrong_count', 0)
        return merged

    def list_words(self) -> list[dict]:
        with self._lock:
            words = self._read_words()
            progress = self._read_progress()
            return [self._merge_state(word, progress) for word in words]

    def get_word(self, word_id: str) -> dict | None:
        with self._lock:
            progress = self._read_progress()
            base = next((word for word in self._read_words() if word.get('id') == word_id), None)
            return None if base is None else self._merge_state(base, progress)

    def create_word(self, word: dict) -> None:
        with self._lock:
            words = self._read_words()
            base = {key: value for key, value in word.items() if key not in _STATE_FIELDS}
            words.append(base)
            self._write_words(words)

            progress = self._read_progress()
            progress[str(word['id'])] = {
                key: word[key]
                for key in _STATE_FIELDS
                if key in word
            }
            self._write_progress(progress)

    def replace_word(self, word_id: str, updated: dict) -> None:
        with self._lock:
            words = self._read_words()
            found = False
            for index, word in enumerate(words):
                if word.get('id') != word_id:
                    continue
                base_updated = {
                    key: value
                    for key, value in updated.items()
                    if key not in _STATE_FIELDS
                }
                if base_updated != word:
                    words[index] = base_updated
                    self._write_words(words)
                found = True
                break
            if not found:
                raise KeyError(word_id)

            progress = self._read_progress()
            current_state = progress.get(word_id, {})
            next_state = {
                **current_state,
                **{
                    key: updated[key]
                    for key in _STATE_FIELDS
                    if key in updated
                },
            }
            progress[word_id] = next_state
            self._write_progress(progress)

    def delete_word(self, word_id: str) -> bool:
        with self._lock:
            words = self._read_words()
            filtered = [word for word in words if word.get('id') != word_id]
            if len(filtered) == len(words):
                return False
            self._write_words(filtered)

            progress = self._read_progress()
            if word_id in progress:
                del progress[word_id]
                self._write_progress(progress)
            return True
