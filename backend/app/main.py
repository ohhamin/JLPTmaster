from __future__ import annotations

from datetime import datetime, timezone
import os
from typing import Any, Literal
from uuid import uuid4

from fastapi import Depends, FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI
from pydantic import BaseModel, Field

from .auth_store import AuthStore
from .gamification_store import GamificationStore
from .store import JsonWordStore
from .user_data_store import UserDataStore

app = FastAPI(title='JLPTmaster API', version='0.5.0')
store = JsonWordStore()
auth_store = AuthStore()
user_data = UserDataStore()
gamification = GamificationStore()

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=False,
    allow_methods=['*'],
    allow_headers=['*'],
)

JlptLevel = Literal['N5', 'N4', 'N3', 'N2', 'N1']
_LEVEL_ORDER: tuple[JlptLevel, ...] = ('N5', 'N4', 'N3', 'N2', 'N1')
_STATE_UPDATE_FIELDS = {'favorite', 'known', 'correct_count', 'wrong_count'}


def _block_start(chapter: int) -> int:
    return ((chapter - 1) // 6) * 6 + 1


def _split_scoped_id(word_id: str) -> tuple[str, int | None]:
    base, separator, suffix = word_id.rpartition('@')
    if separator and base and suffix.isdigit():
        return base, int(suffix)
    return word_id, None


def _scope_word(word: dict, chapter: int) -> dict:
    scoped = dict(word)
    scoped['id'] = f"{word.get('id', '')}@{chapter}"
    scoped['study_chapter'] = chapter
    return scoped


def _auth_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail='login required')
    scheme, separator, token = authorization.partition(' ')
    if separator != ' ' or scheme.lower() != 'bearer' or not token.strip():
        raise HTTPException(status_code=401, detail='invalid authorization header')
    return token.strip()


def current_user(authorization: str | None = Header(default=None)) -> dict:
    token = _auth_token(authorization)
    user = auth_store.user_for_session(token)
    if user is None:
        raise HTTPException(status_code=401, detail='session expired or invalid')
    user_data.ensure_user(user)
    return user


def current_token(authorization: str | None = Header(default=None)) -> str:
    token = _auth_token(authorization)
    if auth_store.user_for_session(token) is None:
        raise HTTPException(status_code=401, detail='session expired or invalid')
    return token


def _base_words() -> list[dict]:
    return store.list_words()


def _merge_user_state(
    word: dict,
    user_id: str,
    *,
    known_chapter: int | None = None,
    favorite_ids: set[str] | None = None,
    known_ids: set[str] | None = None,
    stats_map: dict[str, dict] | None = None,
) -> dict:
    merged = dict(word)
    word_id = str(word.get('id', ''))
    level = str(word.get('level', 'N5'))
    chapter = known_chapter if known_chapter is not None else int(word.get('chapter') or 1)
    favorites = favorite_ids if favorite_ids is not None else user_data.favorite_ids(user_id)
    known = known_ids if known_ids is not None else user_data.known_ids(user_id, level, chapter)
    stats = stats_map if stats_map is not None else user_data.stats_map(user_id)
    state = stats.get(word_id, {})
    merged['favorite'] = word_id in favorites
    merged['known'] = word_id in known
    merged['correct_count'] = int(state.get('correct_count') or 0)
    merged['wrong_count'] = int(state.get('wrong_count') or 0)
    merged['study_chapter'] = chapter
    return merged


def _user_words(user_id: str, known_chapter: int | None = None) -> list[dict]:
    words = _base_words()
    favorite_ids = user_data.favorite_ids(user_id)
    stats_map = user_data.stats_map(user_id)
    known_cache: dict[tuple[str, int], set[str]] = {}
    result: list[dict] = []
    for word in words:
        level = str(word.get('level', 'N5'))
        chapter = known_chapter if known_chapter is not None else int(word.get('chapter') or 1)
        cache_key = (level, chapter)
        known_ids = known_cache.setdefault(
            cache_key,
            user_data.known_ids(user_id, level, chapter),
        )
        result.append(
            _merge_user_state(
                word,
                user_id,
                known_chapter=chapter,
                favorite_ids=favorite_ids,
                known_ids=known_ids,
                stats_map=stats_map,
            )
        )
    return result


class AuthCredentials(BaseModel):
    username: str = Field(min_length=3, max_length=30, pattern=r'^[A-Za-z0-9_.-]+$')
    password: str = Field(min_length=4, max_length=128)


class ExampleWord(BaseModel):
    id: str | None = None
    word: str = Field(min_length=1, max_length=80)
    reading: str = Field(default='', max_length=120)
    meaning_ko: str = Field(default='', max_length=300)
    level: JlptLevel | None = None
    example_ja: str = Field(default='', max_length=500)
    example_ko: str = Field(default='', max_length=500)


class WordCreate(BaseModel):
    word: str = Field(min_length=1, max_length=80)
    reading: str = Field(default='', max_length=120)
    meaning_ko: str = Field(min_length=1, max_length=300)
    level: JlptLevel = 'N5'
    chapter: int = Field(default=1, ge=1)
    part_of_speech: str = Field(default='', max_length=80)
    example_ja: str = Field(default='', max_length=500)
    example_reading: str = Field(default='', max_length=700)
    example_ko: str = Field(default='', max_length=500)
    example_words: list[ExampleWord] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    favorite: bool = False
    known: bool = False


class WordUpdate(BaseModel):
    word: str | None = Field(default=None, min_length=1, max_length=80)
    reading: str | None = Field(default=None, max_length=120)
    meaning_ko: str | None = Field(default=None, min_length=1, max_length=300)
    level: JlptLevel | None = None
    chapter: int | None = Field(default=None, ge=1)
    part_of_speech: str | None = Field(default=None, max_length=80)
    example_ja: str | None = Field(default=None, max_length=500)
    example_reading: str | None = Field(default=None, max_length=700)
    example_ko: str | None = Field(default=None, max_length=500)
    example_words: list[ExampleWord] | None = None
    tags: list[str] | None = None
    favorite: bool | None = None
    known: bool | None = None
    correct_count: int | None = Field(default=None, ge=0)
    wrong_count: int | None = Field(default=None, ge=0)


class WordStateUpdate(BaseModel):
    word_id: str = Field(min_length=1, max_length=160)
    chapter: int | None = Field(default=None, ge=1)
    favorite: bool | None = None
    known: bool | None = None
    correct_count: int | None = Field(default=None, ge=0)
    wrong_count: int | None = Field(default=None, ge=0)


class BatchStateUpdate(BaseModel):
    updates: list[WordStateUpdate] = Field(min_length=1, max_length=500)


class RoundIncrement(BaseModel):
    level: JlptLevel
    chapter: int = Field(ge=0)


class RoundSet(BaseModel):
    level: JlptLevel
    chapter: int = Field(ge=0)
    value: int = Field(ge=0)


class FinalKnownUpdate(BaseModel):
    level: JlptLevel
    word_ids: list[str] = Field(default_factory=list, max_length=10000)


class StudyCursorUpdate(BaseModel):
    level: JlptLevel
    chapter: int = Field(ge=0)
    word_id: str | None = Field(default=None, max_length=200)
    queue_word_ids: list[str] | None = Field(default=None, max_length=10000)
    queue_index: int | None = Field(default=None, ge=0)


class SettingsUpdate(BaseModel):
    settings: dict[str, Any]


class RoundRewardClaim(BaseModel):
    level: JlptLevel
    chapter: int = Field(ge=0)
    round_count: int = Field(ge=1)


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok', 'service': 'jlptmaster-api'}


@app.post('/api/auth/signup')
def signup(payload: AuthCredentials) -> dict:
    try:
        first_user = auth_store.user_count() == 0
        user = auth_store.create_user(payload.username, payload.password)
    except ValueError as exc:
        raise HTTPException(status_code=409, detail='이미 사용 중인 아이디입니다.') from exc

    user_data.ensure_user(user)
    if first_user:
        user_data.migrate_legacy_progress(
            str(user['id']),
            os.getenv('PROGRESS_JSON_PATH', '/app/data/progress.json'),
        )
    token = auth_store.create_session(str(user['id']))
    return {'token': token, 'user': user}


@app.post('/api/auth/login')
def login(payload: AuthCredentials) -> dict:
    user = auth_store.authenticate(payload.username, payload.password)
    if user is None:
        raise HTTPException(status_code=401, detail='아이디 또는 비밀번호가 올바르지 않습니다.')
    user_data.ensure_user(user)
    token = auth_store.create_session(str(user['id']))
    return {'token': token, 'user': user}


@app.get('/api/auth/me')
def auth_me(user: dict = Depends(current_user)) -> dict:
    return {'user': user}


@app.post('/api/auth/logout')
def logout(token: str = Depends(current_token)) -> dict[str, bool]:
    auth_store.delete_session(token)
    return {'logged_out': True}


@app.get('/api/levels')
def get_levels(user: dict = Depends(current_user)) -> list[dict]:
    user_id = str(user['id'])
    base_words = _base_words()
    favorites = user_data.favorite_ids(user_id)
    known_map = user_data.known_map(user_id)
    result: list[dict] = []
    for level in _LEVEL_ORDER:
        level_words = [word for word in base_words if word.get('level') == level]
        chapters = sorted({int(word.get('chapter') or 1) for word in level_words})
        completed = 0
        for chapter in chapters:
            start = _block_start(chapter)
            study_words = [
                word
                for word in level_words
                if start <= int(word.get('chapter') or 1) <= chapter
            ]
            known_ids = known_map.get(f'{level}:{chapter}', set())
            if study_words and all(str(word.get('id', '')) in known_ids for word in study_words):
                completed += 1

        result.append(
            {
                'level': level,
                'total': len(level_words),
                'known': sum(
                    1
                    for word in level_words
                    if str(word.get('id', ''))
                    in known_map.get(f"{level}:{int(word.get('chapter') or 1)}", set())
                ),
                'favorites': sum(1 for word in level_words if str(word.get('id', '')) in favorites),
                'chapters': len(chapters),
                'completed_chapters': completed,
            }
        )
    return result


@app.get('/api/chapters')
def get_chapters(
    level: JlptLevel,
    user: dict = Depends(current_user),
) -> list[dict]:
    user_id = str(user['id'])
    base_words = [word for word in _base_words() if word.get('level') == level]
    chapter_numbers = sorted({int(word.get('chapter') or 1) for word in base_words})
    known_map = user_data.known_map(user_id)
    rounds = user_data.rounds(user_id, level)
    result: list[dict] = []
    for chapter in chapter_numbers:
        start = _block_start(chapter)
        chapter_words = [
            word
            for word in base_words
            if start <= int(word.get('chapter') or 1) <= chapter
        ]
        known_ids = known_map.get(f'{level}:{chapter}', set())
        known = sum(1 for word in chapter_words if str(word.get('id', '')) in known_ids)
        total = len(chapter_words)
        result.append(
            {
                'level': level,
                'chapter': chapter,
                'total': total,
                'known': known,
                'completed': total > 0 and known == total,
                'block_start': _block_start(chapter),
                'rounds': rounds.get(chapter, 0),
            }
        )
    return result


@app.get('/api/words')
def get_words(
    level: JlptLevel | None = None,
    chapter: int | None = Query(default=None, ge=1),
    favorite: bool | None = None,
    q: str | None = Query(default=None, max_length=100),
    user: dict = Depends(current_user),
) -> list[dict]:
    user_id = str(user['id'])
    words = _user_words(user_id, known_chapter=chapter)
    if level:
        words = [word for word in words if word.get('level') == level]
    if chapter is not None:
        start = _block_start(chapter)
        words = [
            word
            for word in words
            if start <= int(word.get('chapter') or 1) <= chapter
        ]
    if favorite is not None:
        words = [word for word in words if bool(word.get('favorite', False)) is favorite]
    if q:
        needle = q.strip().lower()
        words = [
            word
            for word in words
            if needle in word.get('word', '').lower()
            or needle in word.get('reading', '').lower()
            or needle in word.get('meaning_ko', '').lower()
        ]
    if chapter is not None:
        words = [_scope_word(word, chapter) for word in words]
    return words


@app.get('/api/words/{word_id}')
def get_word(
    word_id: str,
    chapter: int | None = Query(default=None, ge=1),
    user: dict = Depends(current_user),
) -> dict:
    base_id, scoped_chapter = _split_scoped_id(word_id)
    effective_chapter = chapter or scoped_chapter
    base = store.get_word(base_id)
    if base is None:
        raise HTTPException(status_code=404, detail='word not found')
    merged = _merge_user_state(
        base,
        str(user['id']),
        known_chapter=effective_chapter,
    )
    return _scope_word(merged, effective_chapter) if scoped_chapter is not None and effective_chapter else merged


@app.post('/api/words', status_code=201)
def create_word(payload: WordCreate, user: dict = Depends(current_user)) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    word = {
        'id': str(uuid4()),
        **payload.model_dump(),
        'correct_count': 0,
        'wrong_count': 0,
        'created_at': now,
        'updated_at': now,
    }
    store.create_word(word)
    base = store.get_word(word['id']) or word
    user_id = str(user['id'])
    if payload.favorite:
        user_data.set_favorite(user_id, word['id'], True)
    if payload.known:
        user_data.set_known(user_id, word['id'], payload.level, payload.chapter, True)
    return _merge_user_state(base, user_id, known_chapter=payload.chapter)


@app.put('/api/words/{word_id}')
def update_word(
    word_id: str,
    payload: WordUpdate,
    study_chapter: int | None = Query(default=None, ge=1),
    user: dict = Depends(current_user),
) -> dict:
    base_id, scoped_chapter = _split_scoped_id(word_id)
    base = store.get_word(base_id)
    if base is None:
        raise HTTPException(status_code=404, detail='word not found')

    user_id = str(user['id'])
    effective_chapter = study_chapter or scoped_chapter or int(base.get('chapter') or 1)
    changes = payload.model_dump(exclude_none=True)
    now = datetime.now(timezone.utc).isoformat()

    if set(changes).issubset(_STATE_UPDATE_FIELDS):
        if 'favorite' in changes:
            user_data.set_favorite(user_id, base_id, bool(changes['favorite']))
        if 'known' in changes:
            user_data.set_known(
                user_id,
                base_id,
                str(base.get('level', 'N5')),
                effective_chapter,
                bool(changes['known']),
            )
        stat_changes = {
            key: changes[key]
            for key in ('correct_count', 'wrong_count')
            if key in changes
        }
        if stat_changes:
            stat_changes['updated_at'] = now
            user_data.update_stats(user_id, base_id, stat_changes)
        merged = _merge_user_state(base, user_id, known_chapter=effective_chapter)
        return _scope_word(merged, effective_chapter) if scoped_chapter is not None else merged

    lexical_changes = {key: value for key, value in changes.items() if key not in _STATE_UPDATE_FIELDS}
    lexical_changes['updated_at'] = now
    updated = {**base, **lexical_changes}
    store.replace_word(base_id, updated)
    refreshed = store.get_word(base_id) or updated
    return _merge_user_state(refreshed, user_id, known_chapter=effective_chapter)


@app.post('/api/progress/batch')
def update_progress_batch(
    payload: BatchStateUpdate,
    user: dict = Depends(current_user),
) -> dict:
    user_id = str(user['id'])
    known_updates: list[tuple[str, str, int, bool]] = []
    for item in payload.updates:
        base_id, scoped_chapter = _split_scoped_id(item.word_id)
        base = store.get_word(base_id)
        if base is None:
            raise HTTPException(status_code=404, detail=f'word not found: {base_id}')
        chapter = item.chapter or scoped_chapter or int(base.get('chapter') or 1)
        level = str(base.get('level', 'N5'))
        if item.known is not None:
            known_updates.append((base_id, level, chapter, bool(item.known)))
        if item.favorite is not None:
            user_data.set_favorite(user_id, base_id, bool(item.favorite))
        stat_changes: dict[str, Any] = {}
        if item.correct_count is not None:
            stat_changes['correct_count'] = item.correct_count
        if item.wrong_count is not None:
            stat_changes['wrong_count'] = item.wrong_count
        if stat_changes:
            stat_changes['updated_at'] = datetime.now(timezone.utc).isoformat()
            user_data.update_stats(user_id, base_id, stat_changes)
    if known_updates:
        user_data.set_known_batch(user_id, known_updates)
    return {'updated': len(payload.updates)}


@app.get('/api/progress/rounds')
def get_rounds(
    level: JlptLevel,
    user: dict = Depends(current_user),
) -> dict:
    rounds = user_data.rounds(str(user['id']), level)
    return {'level': level, 'rounds': {str(key): value for key, value in rounds.items()}}


@app.post('/api/progress/rounds/increment')
def increment_round(
    payload: RoundIncrement,
    user: dict = Depends(current_user),
) -> dict:
    value = user_data.increment_round(
        str(user['id']),
        payload.level,
        payload.chapter,
    )
    return {'level': payload.level, 'chapter': payload.chapter, 'rounds': value}


@app.put('/api/progress/rounds')
def set_round(
    payload: RoundSet,
    user: dict = Depends(current_user),
) -> dict:
    value = user_data.set_round(
        str(user['id']),
        payload.level,
        payload.chapter,
        payload.value,
    )
    return {'level': payload.level, 'chapter': payload.chapter, 'rounds': value}


@app.get('/api/progress/final-known')
def get_final_known(
    level: JlptLevel,
    user: dict = Depends(current_user),
) -> dict:
    ids = sorted(user_data.final_known(str(user['id']), level))
    return {'level': level, 'word_ids': ids}


@app.put('/api/progress/final-known')
def set_final_known(
    payload: FinalKnownUpdate,
    user: dict = Depends(current_user),
) -> dict:
    ids = {str(item) for item in payload.word_ids if str(item).strip()}
    user_data.set_final_known(str(user['id']), payload.level, ids)
    return {'level': payload.level, 'word_ids': sorted(ids)}


@app.get('/api/progress/cursor')
def get_study_cursor(
    level: JlptLevel,
    chapter: int = Query(ge=0),
    user: dict = Depends(current_user),
) -> dict:
    state = user_data.study_cursor_state(str(user['id']), level, chapter)
    return {
        'level': level,
        'chapter': chapter,
        **state,
    }


@app.put('/api/progress/cursor')
def set_study_cursor(
    payload: StudyCursorUpdate,
    user: dict = Depends(current_user),
) -> dict:
    state = user_data.set_study_cursor_state(
        str(user['id']),
        payload.level,
        payload.chapter,
        payload.word_id,
        payload.queue_word_ids,
        payload.queue_index,
    )
    return {
        'level': payload.level,
        'chapter': payload.chapter,
        **state,
    }


@app.get('/api/settings')
def get_settings(user: dict = Depends(current_user)) -> dict:
    return {'settings': user_data.settings(str(user['id']))}


@app.patch('/api/settings')
def update_settings(
    payload: SettingsUpdate,
    user: dict = Depends(current_user),
) -> dict:
    settings = user_data.update_settings(str(user['id']), payload.settings)
    return {'settings': settings}


@app.get('/api/account/leveling')
def get_account_leveling(user: dict = Depends(current_user)) -> dict:
    return gamification.status(str(user['id']))


@app.post('/api/account/attendance')
def claim_attendance(user: dict = Depends(current_user)) -> dict:
    return gamification.claim_daily_attendance(str(user['id']))


@app.post('/api/account/round-reward')
def claim_round_reward(
    payload: RoundRewardClaim,
    user: dict = Depends(current_user),
) -> dict:
    user_id = str(user['id'])
    actual_round = user_data.rounds(user_id, payload.level).get(payload.chapter, 0)
    if actual_round < payload.round_count:
        raise HTTPException(status_code=409, detail='round completion is not recorded yet')
    return gamification.award_round(
        user_id,
        level=payload.level,
        chapter=payload.chapter,
        round_count=payload.round_count,
    )


@app.post('/api/words/{word_id}/explain')
def explain_word(word_id: str, user: dict = Depends(current_user)) -> dict[str, str]:
    base_id, scoped_chapter = _split_scoped_id(word_id)
    word = store.get_word(base_id)
    if word is None:
        raise HTTPException(status_code=404, detail='word not found')

    api_key = os.getenv('OPENAI_API_KEY', '').strip()
    if not api_key:
        raise HTTPException(status_code=503, detail='OpenAI API key is not configured')

    model = os.getenv('OPENAI_MODEL', 'gpt-6-luna').strip() or 'gpt-6-luna'
    target = word.get('word', '')
    reading = word.get('reading', '')
    example = word.get('example_ja', '')
    prompt = f'''저는 일본어를 공부하는 한국어 원어민입니다. 아래 요청사항에 맞춰 상세한 설명을 부탁드립니다.

1.  단어 설명
    * 단어: {target} ({reading})
    * 요구사항: 이 단어의 기본적인 의미, 함께 자주 쓰이는 표현(연어)을 알려주세요. 필요하다면 문맥에 따른 뉘앙스 차이도 알려주세요.

2.  예문 분석
    * 예문: {example}
    * 요구사항:
        * a. 전체 문장의 자연스러운 한국어 번역
        * b. 문법 분석: 문장의 구조와 핵심 문법 포인트를 짚어주세요.
        * c. 어휘 설명: {target} 외에 알아둬야 할 주요 단어나 표현이 있다면 설명해주세요.
'''

    try:
        client = OpenAI(api_key=api_key)
        response = client.responses.create(
            model=model,
            input=prompt,
            max_output_tokens=1600,
        )
        text = (response.output_text or '').strip()
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f'OpenAI request failed ({type(exc).__name__})',
        ) from exc

    if not text:
        raise HTTPException(status_code=502, detail='OpenAI returned an empty response')
    return {'word_id': word_id, 'model': model, 'content': text}


@app.delete('/api/words/{word_id}')
def delete_word(word_id: str, user: dict = Depends(current_user)) -> dict[str, bool]:
    base_id, _ = _split_scoped_id(word_id)
    if not store.delete_word(base_id):
        raise HTTPException(status_code=404, detail='word not found')
    return {'deleted': True}
