from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .store import JsonWordStore

app = FastAPI(title='JLPTmaster API', version='0.1.0')
store = JsonWordStore()

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=False,
    allow_methods=['*'],
    allow_headers=['*'],
)

JlptLevel = Literal['N5', 'N4', 'N3', 'N2', 'N1']


class WordCreate(BaseModel):
    word: str = Field(min_length=1, max_length=80)
    reading: str = Field(default='', max_length=120)
    meaning_ko: str = Field(min_length=1, max_length=300)
    level: JlptLevel = 'N5'
    example_ja: str = Field(default='', max_length=500)
    example_ko: str = Field(default='', max_length=500)
    tags: list[str] = Field(default_factory=list)
    favorite: bool = False


class WordUpdate(BaseModel):
    word: str | None = Field(default=None, min_length=1, max_length=80)
    reading: str | None = Field(default=None, max_length=120)
    meaning_ko: str | None = Field(default=None, min_length=1, max_length=300)
    level: JlptLevel | None = None
    example_ja: str | None = Field(default=None, max_length=500)
    example_ko: str | None = Field(default=None, max_length=500)
    tags: list[str] | None = None
    favorite: bool | None = None
    correct_count: int | None = Field(default=None, ge=0)
    wrong_count: int | None = Field(default=None, ge=0)


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok', 'service': 'jlptmaster-api'}


@app.get('/api/words')
def get_words(
    level: JlptLevel | None = None,
    q: str | None = Query(default=None, max_length=100),
) -> list[dict]:
    words = store.list_words()
    if level:
        words = [word for word in words if word.get('level') == level]
    if q:
        needle = q.strip().lower()
        words = [
            word
            for word in words
            if needle in word.get('word', '').lower()
            or needle in word.get('reading', '').lower()
            or needle in word.get('meaning_ko', '').lower()
        ]
    return words


@app.post('/api/words', status_code=201)
def create_word(payload: WordCreate) -> dict:
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
    return word


@app.put('/api/words/{word_id}')
def update_word(word_id: str, payload: WordUpdate) -> dict:
    current = store.get_word(word_id)
    if current is None:
        raise HTTPException(status_code=404, detail='word not found')
    changes = payload.model_dump(exclude_none=True)
    changes['updated_at'] = datetime.now(timezone.utc).isoformat()
    updated = {**current, **changes}
    store.replace_word(word_id, updated)
    return updated


@app.delete('/api/words/{word_id}', status_code=204)
def delete_word(word_id: str) -> None:
    if not store.delete_word(word_id):
        raise HTTPException(status_code=404, detail='word not found')
