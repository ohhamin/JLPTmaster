from __future__ import annotations

import json
import os
import threading
from pathlib import Path


class JsonWordStore:
    def __init__(self) -> None:
        path = os.getenv('WORDS_JSON_PATH', '/app/data/words.json')
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()
        if not self.path.exists():
            self._write([])

    def _read(self) -> list[dict]:
        with self.path.open('r', encoding='utf-8') as file:
            data = json.load(file)
        if not isinstance(data, list):
            raise ValueError('words.json must contain a JSON array')
        return data

    def _write(self, words: list[dict]) -> None:
        temp_path = self.path.with_suffix('.tmp')
        with temp_path.open('w', encoding='utf-8') as file:
            json.dump(words, file, ensure_ascii=False, indent=2)
            file.write('\n')
        temp_path.replace(self.path)

    def list_words(self) -> list[dict]:
        with self._lock:
            return self._read()

    def get_word(self, word_id: str) -> dict | None:
        with self._lock:
            return next((word for word in self._read() if word.get('id') == word_id), None)

    def create_word(self, word: dict) -> None:
        with self._lock:
            words = self._read()
            words.append(word)
            self._write(words)

    def replace_word(self, word_id: str, updated: dict) -> None:
        with self._lock:
            words = self._read()
            for index, word in enumerate(words):
                if word.get('id') == word_id:
                    words[index] = updated
                    self._write(words)
                    return
            raise KeyError(word_id)

    def delete_word(self, word_id: str) -> bool:
        with self._lock:
            words = self._read()
            filtered = [word for word in words if word.get('id') != word_id]
            if len(filtered) == len(words):
                return False
            self._write(filtered)
            return True
