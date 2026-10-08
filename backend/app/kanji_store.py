from __future__ import annotations

import json
import os
import threading
from pathlib import Path


def is_kanji(char: str) -> bool:
    if len(char) != 1:
        return False
    code = ord(char)
    return (
        0x3400 <= code <= 0x9FFF
        or 0xF900 <= code <= 0xFAFF
        or 0x20000 <= code <= 0x2FA1F
    )


class KanjiStore:
    """Shared per-character dictionary, independent of learner progress."""

    def __init__(self) -> None:
        self.path = Path(os.getenv('KANJI_JSON_PATH', '/app/data/kanji.json'))
        self._lock = threading.RLock()
        self._mtime_ns: int | None = None
        self._entries: dict[str, dict] = {}

    def _refresh(self) -> None:
        # Enrichment writes via atomic rename. Reload changes without restarting
        # the API, and keep serving the previous snapshot on a transient error.
        with self._lock:
            try:
                mtime = self.path.stat().st_mtime_ns
            except FileNotFoundError:
                mtime = None
            if mtime == self._mtime_ns:
                return
            if mtime is None:
                self._entries = {}
                self._mtime_ns = None
                return
            try:
                with self.path.open('r', encoding='utf-8') as file:
                    loaded = json.load(file)
                if not isinstance(loaded, dict):
                    return
            except (ValueError, OSError):
                return
            self._entries = {
                ch: data
                for ch, data in loaded.items()
                if is_kanji(ch) and isinstance(data, dict)
            }
            self._mtime_ns = mtime

    def for_word(self, text: str) -> list[dict]:
        self._refresh()
        with self._lock:
            result = []
            seen: set[str] = set()
            for ch in text:
                if ch in seen or not is_kanji(ch):
                    continue
                seen.add(ch)
                data = self._entries.get(ch)
                if data is None:
                    continue
                result.append({
                    'character': ch,
                    'meaning_ko': str(data.get('meaning_ko') or ''),
                    'onyomi': list(data.get('onyomi') or []),
                    'kunyomi': list(data.get('kunyomi') or []),
                })
            return result
