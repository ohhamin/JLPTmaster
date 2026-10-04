from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import threading
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4


class AuthStore:
    """Tiny JSON-backed auth/session store designed to be replaceable by a DB later."""

    _PBKDF2_ITERATIONS = 210_000

    def __init__(self) -> None:
        users_path = os.getenv('USERS_JSON_PATH', '/app/data/users.json')
        sessions_path = os.getenv('SESSIONS_JSON_PATH', '/app/data/sessions.json')
        self.users_path = Path(users_path)
        self.sessions_path = Path(sessions_path)
        self.users_path.parent.mkdir(parents=True, exist_ok=True)
        self.sessions_path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()
        if not self.users_path.exists():
            self._write_json(self.users_path, {'users': {}})
        if not self.sessions_path.exists():
            self._write_json(self.sessions_path, {'sessions': {}})

    @staticmethod
    def _write_json(path: Path, value: object) -> None:
        temp = path.with_suffix(path.suffix + '.tmp')
        with temp.open('w', encoding='utf-8') as file:
            json.dump(value, file, ensure_ascii=False, separators=(',', ':'))
            file.write('\n')
        temp.replace(path)

    @staticmethod
    def _read_json(path: Path, fallback: dict) -> dict:
        try:
            with path.open('r', encoding='utf-8') as file:
                value = json.load(file)
            return value if isinstance(value, dict) else dict(fallback)
        except (OSError, json.JSONDecodeError):
            return dict(fallback)

    @staticmethod
    def _username_key(username: str) -> str:
        return username.strip().lower()

    @staticmethod
    def _now() -> str:
        return datetime.now(timezone.utc).isoformat()

    def user_count(self) -> int:
        with self._lock:
            data = self._read_json(self.users_path, {'users': {}})
            users = data.get('users') or {}
            return len(users) if isinstance(users, dict) else 0

    def create_user(self, username: str, password: str) -> dict:
        clean_username = username.strip()
        key = self._username_key(clean_username)
        with self._lock:
            data = self._read_json(self.users_path, {'users': {}})
            users = data.setdefault('users', {})
            if key in users:
                raise ValueError('username already exists')

            salt = secrets.token_bytes(16)
            digest = hashlib.pbkdf2_hmac(
                'sha256',
                password.encode('utf-8'),
                salt,
                self._PBKDF2_ITERATIONS,
            )
            user = {
                'id': str(uuid4()),
                'username': clean_username,
                'password_hash': base64.b64encode(digest).decode('ascii'),
                'password_salt': base64.b64encode(salt).decode('ascii'),
                'password_iterations': self._PBKDF2_ITERATIONS,
                'created_at': self._now(),
            }
            users[key] = user
            self._write_json(self.users_path, data)
            return self.public_user(user)

    def authenticate(self, username: str, password: str) -> dict | None:
        key = self._username_key(username)
        with self._lock:
            data = self._read_json(self.users_path, {'users': {}})
            raw = (data.get('users') or {}).get(key)
            if not isinstance(raw, dict):
                return None
            try:
                salt = base64.b64decode(str(raw['password_salt']))
                expected = base64.b64decode(str(raw['password_hash']))
                iterations = int(raw.get('password_iterations') or self._PBKDF2_ITERATIONS)
            except (KeyError, ValueError, TypeError):
                return None
            actual = hashlib.pbkdf2_hmac(
                'sha256',
                password.encode('utf-8'),
                salt,
                iterations,
            )
            if not hmac.compare_digest(actual, expected):
                return None
            return self.public_user(raw)

    def get_user(self, user_id: str) -> dict | None:
        with self._lock:
            data = self._read_json(self.users_path, {'users': {}})
            for raw in (data.get('users') or {}).values():
                if isinstance(raw, dict) and str(raw.get('id')) == user_id:
                    return self.public_user(raw)
            return None

    @staticmethod
    def public_user(user: dict) -> dict:
        return {
            'id': str(user.get('id', '')),
            'username': str(user.get('username', '')),
            'created_at': str(user.get('created_at', '')),
        }

    def create_session(self, user_id: str) -> str:
        token = secrets.token_urlsafe(32)
        with self._lock:
            data = self._read_json(self.sessions_path, {'sessions': {}})
            sessions = data.setdefault('sessions', {})
            sessions[token] = {
                'user_id': user_id,
                'created_at': self._now(),
            }
            self._write_json(self.sessions_path, data)
        return token

    def user_for_session(self, token: str) -> dict | None:
        with self._lock:
            data = self._read_json(self.sessions_path, {'sessions': {}})
            session = (data.get('sessions') or {}).get(token)
            if not isinstance(session, dict):
                return None
            user_id = str(session.get('user_id', ''))
        return self.get_user(user_id)

    def delete_session(self, token: str) -> None:
        with self._lock:
            data = self._read_json(self.sessions_path, {'sessions': {}})
            sessions = data.setdefault('sessions', {})
            sessions.pop(token, None)
            self._write_json(self.sessions_path, data)
