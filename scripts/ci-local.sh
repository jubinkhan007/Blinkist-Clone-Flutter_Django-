#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# Blinkist Clone - Local CI/CD Matrix Runner
# Mirrors .github/workflows/production-ci.yml for fast local pre-push checks.
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RUN_BACKEND=0
RUN_WEB=0
RUN_MOBILE=0
RUN_INFRA=0

if [ $# -eq 0 ]; then
  RUN_BACKEND=1
  RUN_WEB=1
  RUN_MOBILE=1
  RUN_INFRA=1
else
  for arg in "$@"; do
    case "$arg" in
      --all) RUN_BACKEND=1; RUN_WEB=1; RUN_MOBILE=1; RUN_INFRA=1 ;;
      --backend) RUN_BACKEND=1 ;;
      --web) RUN_WEB=1 ;;
      --mobile) RUN_MOBILE=1 ;;
      --infra) RUN_INFRA=1 ;;
      -h|--help)
        echo "Usage: $0 [--all | --backend | --web | --mobile | --infra]"
        exit 0
        ;;
      *)
        echo "❌ Unknown option: $arg"
        echo "Usage: $0 [--all | --backend | --web | --mobile | --infra]"
        exit 1
        ;;
    esac
  done
fi

echo "=================================================================="
echo " 🧪 Blinkist Clone - Local CI Pipeline Verification"
echo "=================================================================="

if [ "$RUN_BACKEND" -eq 1 ]; then
  echo ""
  echo "── [1/4] Django Backend Check, Migrations & Test Suite ──────────"
  PYTHON_BIN="python3"
  if [ -x "$ROOT_DIR/backend/venv/bin/python" ]; then
    PYTHON_BIN="$ROOT_DIR/backend/venv/bin/python"
  fi
  (
    cd "$ROOT_DIR/backend"
    SECRET_KEY="ci-local-secret-key" DEBUG="True" "$PYTHON_BIN" manage.py check
    SECRET_KEY="ci-local-secret-key" DEBUG="True" "$PYTHON_BIN" manage.py makemigrations --check --dry-run
    SECRET_KEY="ci-local-secret-key" DEBUG="True" "$PYTHON_BIN" manage.py test
  )
  echo "✅ Backend checks passed!"
fi

if [ "$RUN_WEB" -eq 1 ]; then
  echo ""
  echo "── [2/4] Next.js Web Client TypeCheck & Production Build ────────"
  (
    cd "$ROOT_DIR/web"
    npx tsc --noEmit
    NEXT_TELEMETRY_DISABLED=1 NODE_ENV=production NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1 npm run build
  )
  echo "✅ Web client build passed!"
fi

if [ "$RUN_MOBILE" -eq 1 ]; then
  echo ""
  echo "── [3/4] Flutter Mobile Static Analysis & Unit Tests ────────────"
  (
    cd "$ROOT_DIR/mobile"
    flutter analyze --no-fatal-infos
    flutter test
  )
  echo "✅ Flutter mobile checks passed!"
fi

if [ "$RUN_INFRA" -eq 1 ]; then
  echo ""
  echo "── [4/4] Docker Compose, Monitoring & Shell Script Validation ───"
  SECRET_KEY="ci-docker-secret" POSTGRES_PASSWORD="ci-pg-pwd" REDIS_PASSWORD="ci-redis-pwd" \
    docker compose config --quiet
  bash -n "$ROOT_DIR/scripts/prod-deploy.sh" "$ROOT_DIR/scripts/test-alert.sh" \
    "$ROOT_DIR/scripts/ci-local.sh" "$ROOT_DIR/backend/entrypoint.sh"
  python3 -m json.tool "$ROOT_DIR/monitoring/grafana/dashboards/blinkist_overview.json" >/dev/null
  echo "✅ Infrastructure & config validation passed!"
fi

echo ""
echo "=================================================================="
echo " 🎉 All selected CI checks completed successfully!"
echo "=================================================================="
