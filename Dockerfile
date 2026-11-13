# Same Dockerfile for local Docker/Minikube and AWS EC2. Version/colour are baked in via build args.
FROM python:3.12-slim

ARG APP_VERSION=1.0.0
ARG DEPLOYMENT_COLOR=standard

LABEL org.opencontainers.image.title="healthcare-app" \
      org.opencontainers.image.version="${APP_VERSION}" \
      release.color="${DEPLOYMENT_COLOR}"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    APP_HOST=0.0.0.0 \
    APP_PORT=8080 \
    APP_VERSION=${APP_VERSION} \
    DEPLOYMENT_COLOR=${DEPLOYMENT_COLOR}

RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 10001 appgrp \
 && useradd --system --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin appusr

WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ .

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/health' % os.getenv('APP_PORT','8080'), timeout=2)"

# One worker + threads: patient data is held in memory (demo app, no database).
CMD ["sh", "-c", "exec gunicorn --bind ${APP_HOST}:${APP_PORT} --workers 1 --threads 4 --worker-tmp-dir /tmp --access-logfile - app:app"]
