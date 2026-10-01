FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /service

COPY backend/requirements.txt /service/backend/requirements.txt
RUN pip install --no-cache-dir -r /service/backend/requirements.txt

COPY backend /service/backend

CMD ["sh", "-c", "uvicorn backend.app.main:app --host 0.0.0.0 --port ${PORT}"]

