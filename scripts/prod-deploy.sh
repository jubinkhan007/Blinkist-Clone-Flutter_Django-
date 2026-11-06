#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# Blinkist Clone - Automated Production Deployment Script
# ==============================================================================

echo "=================================================================="
echo " 🚀 Blinkist Clone - Live Production Deployment"
echo "=================================================================="

# 1. Prerequisite verification
command -v docker >/dev/null 2>&1 || { echo >&2 "❌ Docker is required but not installed. Aborting."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo >&2 "❌ Docker Compose v2 is required. Aborting."; exit 1; }

# 2. Check for environment configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env ]; then
  if [ -f .env.production ]; then
    echo "ℹ️  Using .env.production as environment configuration..."
    cp .env.production .env
  else
    echo "⚠️  No .env file found in root directory!"
    echo "ℹ️  Creating .env from .env.production.example..."
    cp .env.production.example .env
    echo "⚠️  Please update your production secrets in .env before running live traffic."
  fi
fi

# 3. Validate Docker Compose configuration
echo "🔍 Validating docker-compose.yml configuration..."
docker compose config --quiet
echo "✅ Docker Compose syntax validated."

# 4. Build containers
echo "📦 Building production container images (backend, celery, web, nginx)..."
docker compose build --pull

# 5. Start or update the production stack
echo "🚀 Spinning up production containers in background..."
docker compose up -d

# 6. Wait for backend health check
echo "⏳ Waiting for backend and database migrations to complete..."
ATTEMPTS=0
MAX_ATTEMPTS=30
BACKEND_HEALTHY=0

until [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; do
  STATUS=$(docker inspect --format='{{json .State.Health.Status}}' blinkist_backend 2>/dev/null || echo "\"unknown\"")
  if [ "$STATUS" = "\"healthy\"" ]; then
    BACKEND_HEALTHY=1
    break
  fi
  echo "   ... waiting for blinkist_backend to report healthy ($((ATTEMPTS + 1))/$MAX_ATTEMPTS - current: $STATUS)"
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
done

if [ $BACKEND_HEALTHY -eq 1 ]; then
  echo "✅ Backend container is healthy and serving requests!"
else
  echo "⚠️  Backend container took longer than expected to report healthy."
fi

# 7. Print running services summary
echo "=================================================================="
echo " 📊 Service Status"
echo "=================================================================="
docker compose ps

echo ""
echo "🎉 Deployment completed successfully!"
echo "   - Web App & API Gateway: http://localhost:${PORT:-80}"
echo "   - Health Check:          http://localhost:${PORT:-80}/healthz/"
echo "   - API Root:              http://localhost:${PORT:-80}/api/v1/"
echo "=================================================================="
