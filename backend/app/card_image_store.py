from __future__ import annotations

import base64
import os
from pathlib import Path
import re


_PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'
_WEBP_SIGNATURE = b'RIFF'
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
        # Deliberately extensionless: the file name itself is the user id.
        # The initial bundled artwork is WebP, while edited snapshots are PNG.
        # Reusing one path means edits always overwrite instead of accumulating.
        return self.root / self._safe_user_id(user_id)

    def exists(self, user_id: str) -> bool:
        return self.path_for(user_id).is_file()

    @staticmethod
    def media_type_for_bytes(data: bytes) -> str:
        if data.startswith(_PNG_SIGNATURE):
            return 'image/png'
        if data.startswith(_WEBP_SIGNATURE) and data[8:12] == b'WEBP':
            return 'image/webp'
        return 'application/octet-stream'

    def media_type(self, user_id: str) -> str:
        path = self.path_for(user_id)
        try:
            return self.media_type_for_bytes(path.read_bytes()[:16])
        except OSError:
            return 'application/octet-stream'

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
        if self.media_type_for_bytes(decoded) not in {'image/png', 'image/webp'}:
            return None
        self._default_bytes = decoded
        return decoded

    def _atomic_write(self, target: Path, data: bytes) -> Path:
        target.parent.mkdir(parents=True, exist_ok=True)
        temp = target.with_name(f'{target.name}.tmp')
        temp.write_bytes(data)
        os.replace(temp, target)
        return target

    def ensure_default(self, user_id: str) -> Path | None:
        target = self.path_for(user_id)
        if target.is_file():
            return target
        default = self._load_default()
        if default is None:
            return None
        return self._atomic_write(target, default)

    def save(self, user_id: str, png_bytes: bytes) -> Path:
        if not png_bytes.startswith(_PNG_SIGNATURE):
            raise ValueError('not a png image')
        return self._atomic_write(self.path_for(user_id), png_bytes)
