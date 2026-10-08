# JLPTmaster

개인용 JLPT 단어 학습 앱입니다. Flutter 앱 + FastAPI(JSON 저장소) 구조이며 로그인/세션 없이 한 명이 사용합니다.

## 학습 흐름

1. N5 → N1 등급 선택
2. 등급 안에서 챕터 선택 (데이터 생성 시 챕터당 최대 50단어)
3. 단어 + 예문을 먼저 보고 `히라가나` / `의미`를 필요할 때 공개
4. `알고 있음`은 해당 단어를 학습 완료로 저장하고 다음 단어로 이동
5. `다시 학습`은 완료 처리 없이 다음 단어로 이동
6. 별 버튼으로 즐겨찾기 추가
7. 하단 `즐겨찾기` 탭에서 상세 화면 및 예문 속 JLPT 단어 확인
8. 상세 화면의 AI 설명에서 OpenAI API로 단어/예문 분석 요청

## 구조

- `lib/` Flutter 앱
- `backend/` FastAPI + JSON 단어 저장소 (`words.json` 정적 데이터 + `progress.json` 개인 학습 상태)
- `deploy/` AWS 배포용 설정
- `.github/workflows/flutter-build.yml` Android APK 자동 빌드/테스트

## 단어 JSON 구조

```json
{
  "id": "uuid",
  "word": "勉強",
  "reading": "べんきょう",
  "meaning_ko": "공부, 학습",
  "level": "N5",
  "chapter": 1,
  "part_of_speech": "명사·する동사",
  "example_ja": "毎日、日本語を勉強します。",
  "example_reading": "まいにち、にほんごをべんきょうします。",
  "example_ko": "매일 일본어를 공부합니다.",
  "example_words": [
    {
      "id": null,
      "word": "毎日",
      "reading": "まいにち",
      "meaning_ko": "매일",
      "level": "N5"
    }
  ],
  "tags": ["기본"],
  "favorite": false,
  "known": false,
  "correct_count": 0,
  "wrong_count": 0
}
```

`example_words`에는 예문에 등장하는 **현재 학습 단어 이외의 JLPT 단어**를 넣습니다. 데이터 생성 단계에서 전체 단어 사전과 교차 참조해 채웁니다.

## 한자 사전 사전 적재

단어 표기에 한자가 있는 경우에만 상세 화면에 글자별 뜻·음독·훈독을 표시합니다.
관련 한자는 `backend/data/kanji.json`에 글자당 한 번만 저장하고,
`GET /api/words/{id}`는 해당 단어의 한자 항목만 `kanji` 배열로 반환합니다.
JLPT 등급·해당 한자를 포함하는 다른 단어는 한자 카드에 표시하지 않습니다.

백엔드 Docker 이미지를 갱신한 뒤, 이미 설정된 OpenAI 키로 최초 1회 적재합니다.

```bash
docker exec jlptmaster-api python tools/enrich_kanji.py --dry-run
docker exec jlptmaster-api python tools/enrich_kanji.py --batch-size 16
```

완료된 배치를 매번 원자적으로 파일에 저장하며, 재실행 시 이미 저장된 글자는
GPT에 재요청하지 않습니다. `--limit 16`으로 소규모 시험 실행할 수 있습니다.
`KANJI_OPENAI_MODEL`(기본 `gpt-5-mini`)로 모델을 별도 지정할 수 있습니다.
기존 `words.json` 및 사용자 학습 기록은 수정되지 않습니다.

## 주요 API

- `GET /health`
- `GET /api/levels`
- `GET /api/chapters?level=N5`
- `GET /api/words?level=N5&chapter=1`
- `GET /api/words?favorite=true`
- `GET /api/words/{id}`
- `PUT /api/words/{id}` (`favorite`, `known` 등 부분 갱신)
- `POST /api/words/{id}/explain` (OpenAI 단어/예문 분석)

## OpenAI 설정

백엔드 호스트 환경변수에 아래 값을 둡니다. API 키는 저장소에 커밋하지 않습니다.

```bash
export OPENAI_API_KEY='...'
export OPENAI_MODEL='gpt-6-luna'
```

`docker-compose.yml`이 위 환경변수를 컨테이너로 전달합니다. 즐겨찾기/알고 있음 등 학습 상태는 Git에 커밋되지 않는 `backend/data/progress.json`에 별도 저장되어 단어 원본 JSON을 건드리지 않습니다.

## 로컬 Flutter 실행

```bash
flutter create . --project-name jlptmaster --org com.jlptmaster --platforms=android
flutter pub get
flutter run --dart-define=API_BASE_URL=https://jlptmaster.duckdns.org
```

## 백엔드 로컬 실행

```bash
cd backend
docker compose up -d --build
```
