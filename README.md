# JLPTmaster

개인용 JLPT 단어 학습 앱 기본 골격입니다.

## 구조

- `lib/` Flutter 앱
- `backend/` FastAPI + JSON 단어 저장소
- `deploy/` AWS 배포용 설정
- `.github/workflows/flutter-build.yml` Android APK 자동 빌드

## 단어 JSON 기본 구조

```json
{
  "id": "uuid",
  "word": "勉強",
  "reading": "べんきょう",
  "meaning_ko": "공부",
  "level": "N5",
  "example_ja": "毎日、日本語を勉強します。",
  "example_ko": "매일 일본어를 공부합니다.",
  "tags": ["기본"],
  "favorite": false,
  "correct_count": 0,
  "wrong_count": 0
}
```

## 로컬 Flutter 실행

처음 한 번 플랫폼 파일을 생성합니다.

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

헬스 체크: `GET /health`
단어 목록: `GET /api/words`

로그인/세션은 사용하지 않습니다. 단어 데이터는 `backend/data/words.json`에 저장됩니다.
