from __future__ import annotations

from datetime import datetime, timezone
import os
from typing import Literal
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI
from pydantic import BaseModel, Field

from .store import JsonWordStore

app = FastAPI(title='JLPTmaster API', version='0.2.0')
store = JsonWordStore()

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=False,
    allow_methods=['*'],
    allow_headers=['*'],
)

JlptLevel = Literal['N5', 'N4', 'N3', 'N2', 'N1']
_LEVEL_ORDER: tuple[JlptLevel, ...] = ('N5', 'N4', 'N3', 'N2', 'N1')


class ExampleWord(BaseModel):
    id: str | None = None
    word: str = Field(min_length=1, max_length=80)
    reading: str = Field(default='', max_length=120)
    meaning_ko: str = Field(default='', max_length=300)
    level: JlptLevel | None = None


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


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok', 'service': 'jlptmaster-api'}


@app.get('/api/levels')
def get_levels() -> list[dict]:
    words = store.list_words()
    result: list[dict] = []
    for level in _LEVEL_ORDER:
        level_words = [word for word in words if word.get('level') == level]
        chapters = {int(word.get('chapter') or 1) for word in level_words}
        result.append(
            {
                'level': level,
                'total': len(level_words),
                'known': sum(1 for word in level_words if bool(word.get('known', False))),
                'favorites': sum(1 for word in level_words if bool(word.get('favorite', False))),
                'chapters': len(chapters),
            }
        )
    return result


@app.get('/api/chapters')
def get_chapters(level: JlptLevel) -> list[dict]:
    words = [word for word in store.list_words() if word.get('level') == level]
    grouped: dict[int, list[dict]] = {}
    for word in words:
        chapter = int(word.get('chapter') or 1)
        grouped.setdefault(chapter, []).append(word)

    return [
        {
            'level': level,
            'chapter': chapter,
            'total': len(chapter_words),
            'known': sum(1 for word in chapter_words if bool(word.get('known', False))),
        }
        for chapter, chapter_words in sorted(grouped.items())
    ]


@app.get('/api/words')
def get_words(
    level: JlptLevel | None = None,
    chapter: int | None = Query(default=None, ge=1),
    favorite: bool | None = None,
    q: str | None = Query(default=None, max_length=100),
) -> list[dict]:
    words = store.list_words()
    if level:
        words = [word for word in words if word.get('level') == level]
    if chapter is not None:
        words = [word for word in words if int(word.get('chapter') or 1) == chapter]
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
    return words


@app.get('/api/words/{word_id}')
def get_word(word_id: str) -> dict:
    word = store.get_word(word_id)
    if word is None:
        raise HTTPException(status_code=404, detail='word not found')
    return word


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


@app.post('/api/words/{word_id}/explain')
def explain_word(word_id: str) -> dict[str, str]:
    word = store.get_word(word_id)
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
    except Exception as exc:  # pragma: no cover - depends on external API
        raise HTTPException(
            status_code=502,
            detail=f'OpenAI request failed ({type(exc).__name__})',
        ) from exc

    if not text:
        raise HTTPException(status_code=502, detail='OpenAI returned an empty response')
    return {'word_id': word_id, 'model': model, 'content': text}


@app.delete('/api/words/{word_id}')
def delete_word(word_id: str) -> dict[str, bool]:
    if not store.delete_word(word_id):
        raise HTTPException(status_code=404, detail='word not found')
    return {'deleted': True}
