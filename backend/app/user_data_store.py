from __future__ import annotations

import json
import os
import threading
from pathlib import Path
from typing import Any


class UserDataStore:
    """Per-user JSON persistence split by concern for an easy future DB migration."""

    def __init__(self) -> None:
        root = os.getenv('USER_DATA_ROOT', '/app/data/user_data')
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()

    @staticmethod
    def _write_json(path: Path, value: object) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_suffix(path.suffix + '.tmp')
        with temp.open('w', encoding='utf-8') as file:
            json.dump(value, file, ensure_ascii=False, separators=(',', ':'))
            file.write('\n')
        temp.replace(path)

    @staticmethod
    def _read_json(path: Path, fallback: dict) -> dict:
        if not path.exists():
            return dict(fallback)
        try:
            with path.open('r', encoding='utf-8') as file:
                value = json.load(file)
            return value if isinstance(value, dict) else dict(fallback)
        except (OSError, json.JSONDecodeError):
            return dict(fallback)

    def _dir(self, user_id: str) -> Path:
        return self.root / user_id

    def _path(self, user_id: str, name: str) -> Path:
        return self._dir(user_id) / name

    def ensure_user(self, user: dict) -> None:
        with self._lock:
            directory = self._dir(str(user['id']))
            directory.mkdir(parents=True, exist_ok=True)
            defaults: dict[str, dict] = {
                'profile.json': {
                    'id': str(user['id']),
                    'username': str(user['username']),
                    'created_at': str(user.get('created_at', '')),
                },
                'known.json': {'chapters': {}, 'final': {}},
                'favorites.json': {'word_ids': []},
                'rounds.json': {},
                'settings.json': {},
                'stats.json': {},
            }
            for name, value in defaults.items():
                path = directory / name
                if not path.exists():
                    self._write_json(path, value)

    @staticmethod
    def _chapter_key(level: str, chapter: int) -> str:
        return f'{level.upper()}:{chapter}'

    def known_map(self, user_id: str) -> dict[str, set[str]]:
        with self._lock:
            data = self._read_json(self._path(user_id, 'known.json'), {'chapters': {}, 'final': {}})
            chapters = data.get('chapters') or {}
            return {str(key): set(value or []) for key, value in chapters.items() if isinstance(value, list)}

    def known_ids(self, user_id: str, level: str, chapter: int) -> set[str]:
        with self._lock:
            data = self._read_json(self._path(user_id, 'known.json'), {'chapters': {}, 'final': {}})
            return set((data.get('chapters') or {}).get(self._chapter_key(level, chapter), []) or [])

    def is_known(self, user_id: str, word_id: str, level: str, chapter: int) -> bool:
        return word_id in self.known_ids(user_id, level, chapter)

    def set_known(self, user_id: str, word_id: str, level: str, chapter: int, known: bool) -> None:
        with self._lock:
            path = self._path(user_id, 'known.json')
            data = self._read_json(path, {'chapters': {}, 'final': {}})
            chapters = data.setdefault('chapters', {})
            key = self._chapter_key(level, chapter)
            ids = set(chapters.get(key) or [])
            if known:
                ids.add(word_id)
            else:
                ids.discard(word_id)
            if ids:
                chapters[key] = sorted(ids)
            else:
                chapters.pop(key, None)
            self._write_json(path, data)

    def set_known_batch(self, user_id: str, updates: list[tuple[str, str, int, bool]]) -> None:
        with self._lock:
            path = self._path(user_id, 'known.json')
            data = self._read_json(path, {'chapters': {}, 'final': {}})
            chapters = data.setdefault('chapters', {})
            buckets: dict[str, set[str]] = {}
            for word_id, level, chapter, known in updates:
                key = self._chapter_key(level, chapter)
                ids = buckets.setdefault(key, set(chapters.get(key) or []))
                if known:
                    ids.add(word_id)
                else:
                    ids.discard(word_id)
            for key, ids in buckets.items():
                if ids:
                    chapters[key] = sorted(ids)
                else:
                    chapters.pop(key, None)
            self._write_json(path, data)

    def final_known(self, user_id: str, level: str) -> set[str]:
        with self._lock:
            data = self._read_json(self._path(user_id, 'known.json'), {'chapters': {}, 'final': {}})
            return set((data.get('final') or {}).get(level.upper(), []) or [])

    def set_final_known(self, user_id: str, level: str, word_ids: set[str]) -> None:
        with self._lock:
            path = self._path(user_id, 'known.json')
            data = self._read_json(path, {'chapters': {}, 'final': {}})
            final = data.setdefault('final', {})
            key = level.upper()
            if word_ids:
                final[key] = sorted(word_ids)
            else:
                final.pop(key, None)
            self._write_json(path, data)

    def is_favorite(self, user_id: str, word_id: str) -> bool:
        with self._lock:
            data = self._read_json(self._path(user_id, 'favorites.json'), {'word_ids': []})
            return word_id in (data.get('word_ids') or [])

    def set_favorite(self, user_id: str, word_id: str, favorite: bool) -> None:
        with self._lock:
            path = self._path(user_id, 'favorites.json')
            data = self._read_json(path, {'word_ids': []})
            ids = set(data.get('word_ids') or [])
            if favorite:
                ids.add(word_id)
            else:
                ids.discard(word_id)
            data['word_ids'] = sorted(ids)
            self._write_json(path, data)

    def favorite_ids(self, user_id: str) -> set[str]:
        with self._lock:
            data = self._read_json(self._path(user_id, 'favorites.json'), {'word_ids': []})
            return set(data.get('word_ids') or [])

    def stats_map(self, user_id: str) -> dict[str, dict]:
        with self._lock:
            data = self._read_json(self._path(user_id, 'stats.json'), {})
            return {str(key): dict(value) for key, value in data.items() if isinstance(value, dict)}

    def get_stats(self, user_id: str, word_id: str) -> dict:
        return self.stats_map(user_id).get(word_id, {})

    def update_stats(self, user_id: str, word_id: str, changes: dict) -> None:
        with self._lock:
            path = self._path(user_id, 'stats.json')
            data = self._read_json(path, {})
            state = dict(data.get(word_id) or {})
            state.update(changes)
            data[word_id] = state
            self._write_json(path, data)

    def rounds(self, user_id: str, level: str) -> dict[int, int]:
        prefix = f'{level.upper()}:'
        with self._lock:
            data = self._read_json(self._path(user_id, 'rounds.json'), {})
            result: dict[int, int] = {}
            for key, value in data.items():
                if not str(key).startswith(prefix):
                    continue
                try:
                    result[int(str(key).split(':', 1)[1])] = int(value)
                except (ValueError, TypeError):
                    continue
            return result

    def set_round(self, user_id: str, level: str, chapter: int, value: int) -> int:
        with self._lock:
            path = self._path(user_id, 'rounds.json')
            data = self._read_json(path, {})
            key = self._chapter_key(level, chapter)
            data[key] = max(0, int(value))
            self._write_json(path, data)
            return int(data[key])

    def increment_round(self, user_id: str, level: str, chapter: int) -> int:
        with self._lock:
            path = self._path(user_id, 'rounds.json')
            data = self._read_json(path, {})
            key = self._chapter_key(level, chapter)
            next_value = int(data.get(key) or 0) + 1
            data[key] = next_value
            self._write_json(path, data)
            return next_value

    def settings(self, user_id: str) -> dict:
        with self._lock:
            return self._read_json(self._path(user_id, 'settings.json'), {})

    def update_settings(self, user_id: str, changes: dict) -> dict:
        def merge(target: dict[str, Any], patch: dict[str, Any]) -> dict[str, Any]:
            for key, value in patch.items():
                if isinstance(value, dict) and isinstance(target.get(key), dict):
                    target[key] = merge(dict(target[key]), value)
                else:
                    target[key] = value
            return target

        with self._lock:
            path = self._path(user_id, 'settings.json')
            current = self._read_json(path, {})
            merged = merge(dict(current), changes)
            self._write_json(path, merged)
            return merged

    def migrate_legacy_progress(self, user_id: str, legacy_path: str) -> bool:
        """Assign the old single-user progress.json to the first account once."""
        marker = self._path(user_id, 'legacy_migrated.json')
        with self._lock:
            if marker.exists():
                return False
            source = Path(legacy_path)
            if not source.exists():
                self._write_json(marker, {'migrated': False})
                return False
            try:
                with source.open('r', encoding='utf-8') as file:
                    legacy = json.load(file)
            except (OSError, json.JSONDecodeError):
                self._write_json(marker, {'migrated': False})
                return False
            if not isinstance(legacy, dict):
                self._write_json(marker, {'migrated': False})
                return False

            word_states = legacy.get('word_states') or {}
            if isinstance(word_states, dict):
                favorite_ids = {
                    str(word_id)
                    for word_id, state in word_states.items()
                    if isinstance(state, dict) and bool(state.get('favorite', False))
                }
                if favorite_ids:
                    self._write_json(self._path(user_id, 'favorites.json'), {'word_ids': sorted(favorite_ids)})
                stats: dict[str, dict] = {}
                for word_id, state in word_states.items():
                    if not isinstance(state, dict):
                        continue
                    entry = {
                        key: state[key]
                        for key in ('correct_count', 'wrong_count', 'updated_at')
                        if key in state
                    }
                    if entry:
                        stats[str(word_id)] = entry
                if stats:
                    self._write_json(self._path(user_id, 'stats.json'), stats)

            chapter_known = legacy.get('chapter_known') or {}
            chapters: dict[str, list[str]] = {}
            if isinstance(chapter_known, dict):
                grouped: dict[str, set[str]] = {}
                for raw_key, enabled in chapter_known.items():
                    if not enabled:
                        continue
                    parts = str(raw_key).split(':', 2)
                    if len(parts) != 3:
                        continue
                    level, chapter, word_id = parts
                    if not chapter.isdigit():
                        continue
                    grouped.setdefault(f'{level.upper()}:{int(chapter)}', set()).add(word_id)
                chapters = {key: sorted(ids) for key, ids in grouped.items()}
            if chapters:
                self._write_json(self._path(user_id, 'known.json'), {'chapters': chapters, 'final': {}})

            self._write_json(marker, {'migrated': True})
            return True
