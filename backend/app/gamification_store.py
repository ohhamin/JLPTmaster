from __future__ import annotations

from datetime import datetime, timedelta, timezone
import json
import os
import threading
from pathlib import Path


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except (TypeError, ValueError):
        return default


class GamificationStore:
    """Small JSON-backed leveling store that can later map directly to a DB table."""

    def __init__(self) -> None:
        self.root = Path(os.getenv('USER_DATA_ROOT', '/app/data/user_data'))
        self.root.mkdir(parents=True, exist_ok=True)
        self.xp_per_level = max(1, _env_int('LEVEL_XP_REQUIRED', 30))
        self.daily_xp = max(0, _env_int('DAILY_ATTENDANCE_XP', 5))
        self.round_xp = max(0, _env_int('ROUND_COMPLETION_XP', 30))
        self.timezone_offset_hours = _env_int('APP_TIMEZONE_OFFSET_HOURS', 9)
        self._lock = threading.RLock()

    def _path(self, user_id: str) -> Path:
        return self.root / user_id / 'leveling.json'

    @staticmethod
    def _write_json(path: Path, value: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_suffix(path.suffix + '.tmp')
        with temp.open('w', encoding='utf-8') as file:
            json.dump(value, file, ensure_ascii=False, separators=(',', ':'))
            file.write('\n')
        temp.replace(path)

    def _default(self) -> dict:
        return {
            'level': 1,
            'experience': 0,
            'total_experience': 0,
            'last_attendance_date': None,
            'rewarded_rounds': [],
        }

    def _load(self, user_id: str) -> dict:
        path = self._path(user_id)
        if not path.exists():
            data = self._default()
            self._write_json(path, data)
            return data
        try:
            with path.open('r', encoding='utf-8') as file:
                raw = json.load(file)
        except (OSError, json.JSONDecodeError):
            raw = {}
        data = self._default()
        if isinstance(raw, dict):
            data.update(raw)
        data['level'] = max(1, int(data.get('level') or 1))
        data['experience'] = max(0, int(data.get('experience') or 0))
        data['total_experience'] = max(0, int(data.get('total_experience') or 0))
        data['rewarded_rounds'] = [str(item) for item in (data.get('rewarded_rounds') or [])]
        return data

    def _status(self, data: dict) -> dict:
        return {
            'level': int(data.get('level') or 1),
            'experience': int(data.get('experience') or 0),
            'xp_required': self.xp_per_level,
            'total_experience': int(data.get('total_experience') or 0),
            'last_attendance_date': data.get('last_attendance_date'),
            'daily_attendance_xp': self.daily_xp,
            'round_completion_xp': self.round_xp,
        }

    def status(self, user_id: str) -> dict:
        with self._lock:
            return self._status(self._load(user_id))

    def _award_locked(self, data: dict, amount: int) -> dict:
        amount = max(0, int(amount))
        previous_level = int(data.get('level') or 1)
        if amount > 0:
            data['experience'] = int(data.get('experience') or 0) + amount
            data['total_experience'] = int(data.get('total_experience') or 0) + amount
            while data['experience'] >= self.xp_per_level:
                data['experience'] -= self.xp_per_level
                data['level'] = int(data.get('level') or 1) + 1
        current_level = int(data.get('level') or 1)
        return {
            **self._status(data),
            'xp_gained': amount,
            'previous_level': previous_level,
            'levels_gained': max(0, current_level - previous_level),
            'leveled_up': current_level > previous_level,
        }

    def claim_daily_attendance(self, user_id: str) -> dict:
        with self._lock:
            data = self._load(user_id)
            tz = timezone(timedelta(hours=self.timezone_offset_hours))
            today = datetime.now(tz).date().isoformat()
            if data.get('last_attendance_date') == today:
                return {
                    **self._status(data),
                    'xp_gained': 0,
                    'previous_level': int(data.get('level') or 1),
                    'levels_gained': 0,
                    'leveled_up': False,
                    'attendance_awarded': False,
                }
            data['last_attendance_date'] = today
            reward = self._award_locked(data, self.daily_xp)
            self._write_json(self._path(user_id), data)
            return {**reward, 'attendance_awarded': True}

    def award_round(
        self,
        user_id: str,
        *,
        level: str,
        chapter: int,
        round_count: int,
    ) -> dict:
        with self._lock:
            data = self._load(user_id)
            reward_key = f'{level.upper()}:{int(chapter)}:{int(round_count)}'
            rewarded = set(data.get('rewarded_rounds') or [])
            if reward_key in rewarded:
                return {
                    **self._status(data),
                    'xp_gained': 0,
                    'previous_level': int(data.get('level') or 1),
                    'levels_gained': 0,
                    'leveled_up': False,
                    'round_rewarded': False,
                }
            rewarded.add(reward_key)
            data['rewarded_rounds'] = sorted(rewarded)
            reward = self._award_locked(data, self.round_xp)
            self._write_json(self._path(user_id), data)
            return {**reward, 'round_rewarded': True}
