# Stage 1: Build Python dependencies
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .

# Create an isolated Python environment.
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt \
    && /opt/venv/bin/python -m pip check \
    && /opt/venv/bin/pip uninstall -y pip setuptools wheel


# Stage 2: Production runtime
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Apply available Debian security updates.
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

# Copy installed application dependencies.
COPY --from=builder /opt/venv /opt/venv

# Download the official Amazon RDS CA bundle.
RUN mkdir -p certs \
    && python -c "import urllib.request; urllib.request.urlretrieve('https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem', 'certs/global-bundle.pem')"

# Copy application code.
COPY main.py .

# Create a non-root application user.
RUN useradd --create-home appuser \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]