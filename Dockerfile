FROM python:3.12-slim

# System dependencies for weasyprint, pymupdf, psycopg2, and asyncpg
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf-2.0-0 \
    libffi-dev \
    shared-mime-info \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python backend dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy complete backend code including static web assets
COPY backend/ .

ENV PORT=8000
EXPOSE 8000

# Railway passes $PORT dynamically. Run uvicorn bound to 0.0.0.0:$PORT
CMD sh -c "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"
