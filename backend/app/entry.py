from __future__ import annotations

from fastapi import Depends, HTTPException, Request
from fastapi.responses import FileResponse

from .card_image_store import CardImageStore
from .main import app, auth_store, current_user


card_images = CardImageStore()
_MAX_CARD_BYTES = 8 * 1024 * 1024

# Keep the existing auth implementation untouched, but guarantee that every
# account owns one default Chiikawa card image. The wrappers also cover restored
# sessions, so existing users receive the default file on their next request.
_original_create_user = auth_store.create_user
_original_authenticate = auth_store.authenticate
_original_user_for_session = auth_store.user_for_session


def _create_user_with_default_card(username: str, password: str) -> dict:
    user = _original_create_user(username, password)
    card_images.ensure_default(str(user['id']))
    return user


def _authenticate_with_default_card(username: str, password: str) -> dict | None:
    user = _original_authenticate(username, password)
    if user is not None:
        card_images.ensure_default(str(user['id']))
    return user


def _user_for_session_with_default_card(token: str) -> dict | None:
    user = _original_user_for_session(token)
    if user is not None:
        card_images.ensure_default(str(user['id']))
    return user


auth_store.create_user = _create_user_with_default_card  # type: ignore[method-assign]
auth_store.authenticate = _authenticate_with_default_card  # type: ignore[method-assign]
auth_store.user_for_session = _user_for_session_with_default_card  # type: ignore[method-assign]


@app.get('/api/account/card-image')
def get_card_image(user: dict = Depends(current_user)) -> FileResponse:
    user_id = str(user['id'])
    path = card_images.ensure_default(user_id)
    if path is None or not path.is_file():
        raise HTTPException(status_code=404, detail='card image not found')
    return FileResponse(
        path,
        media_type='image/png',
        filename=f'{user_id}.png',
        headers={'Cache-Control': 'no-store, max-age=0'},
    )


@app.put('/api/account/card-image')
async def put_card_image(
    request: Request,
    user: dict = Depends(current_user),
) -> dict:
    content_type = request.headers.get('content-type', '').split(';', 1)[0].strip().lower()
    if content_type != 'image/png':
        raise HTTPException(status_code=415, detail='card image must be image/png')

    body = await request.body()
    if not body:
        raise HTTPException(status_code=400, detail='empty card image')
    if len(body) > _MAX_CARD_BYTES:
        raise HTTPException(status_code=413, detail='card image is too large')

    user_id = str(user['id'])
    try:
        path = card_images.save(user_id, body)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return {
        'saved': True,
        'file_name': path.name,
        'bytes': len(body),
    }
