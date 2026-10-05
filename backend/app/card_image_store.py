from __future__ import annotations

import base64
import os
from pathlib import Path
import re


_PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'
_SAFE_USER_ID = re.compile(r'^[A-Za-z0-9_-]{1,128}$')


class CardImageStore:
    def __init__(self) -> None:
        self.root = Path(os.getenv('CARD_IMAGE_ROOT', '/app/data/cards'))
        self.default_asset_root = Path(
            os.getenv('DEFAULT_CARD_ASSET_ROOT', '/app/card_assets')
        )
        self.root.mkdir(parents=True, exist_ok=True)
        self._default_bytes: bytes | None = None

    def _safe_user_id(self, user_id: str) -> str:
        value = str(user_id).strip()
        if not _SAFE_USER_ID.fullmatch(value):
            raise ValueError('invalid user id')
        return value

    def path_for(self, user_id: str) -> Path:
        return self.root / f'{self._safe_user_id(user_id)}.png'

    def exists(self, user_id: str) -> bool:
        return self.path_for(user_id).is_file()

    def _load_default(self) -> bytes | None:
        if self._default_bytes is not None:
            return self._default_bytes
        parts = sorted(self.default_asset_root.glob('default_chiikawa_card.part-*'))
        if not parts:
            return None
        encoded = ''.join(part.read_text(encoding='utf-8') for part in parts)
        try:
            decoded = base64.b64decode(encoded, validate=True)
        except Exception:
            return None
        if not decoded.startswith(_PNG_SIGNATURE):
            return None
        self._default_bytes = decoded
        return decoded

    def ensure_default(self, user_id: str) -> Path | None:
        target = self.path_for(user_id)
        if target.is_file():
            return target
        default = self._load_default()
        if default is None:
            return None
        self.save(user_id, default)
        return target

    def save(self, user_id: str, png_bytes: bytes) -> Path:
        if not png_bytes.startswith(_PNG_SIGNATURE):
            raise ValueError('not a png image')
        target = self.path_for(user_id)
        target.parent.mkdir(parents=True, exist_ok=True)
        temp = target.with_suffix('.png.tmp')
        temp.write_bytes(png_bytes)
        os.replace(temp, target)
        return target
