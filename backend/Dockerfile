FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    WORDS_JSON_PATH=/app/data/words.json \
    CARD_IMAGE_ROOT=/app/data/cards \
    DEFAULT_CARD_ASSET_ROOT=/app/card_assets

WORKDIR /app

COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/app ./app
COPY backend/data ./data
COPY assets/cards ./card_assets

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
