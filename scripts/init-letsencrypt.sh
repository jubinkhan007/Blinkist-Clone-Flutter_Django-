#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# Blinkist Clone - Let's Encrypt SSL/TLS Automated Bootstrapper
# Provisions HTTPS certificates via ACME HTTP-01 webroot challenge and
# activates hardened TLS 1.2/1.3 + HSTS + HTTP->HTTPS redirect in Nginx.
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env
fi

DOMAIN="${DOMAIN:-}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
CERTBOT_STAGING="${CERTBOT_STAGING:-0}"
INCLUDE_WWW="${CERTBOT_INCLUDE_WWW:-0}"
FORCE_RENEWAL=0

for arg in "$@"; do
  case "$arg" in
    --staging) CERTBOT_STAGING=1 ;;
    --with-www) INCLUDE_WWW=1 ;;
    --force-renewal) FORCE_RENEWAL=1 ;;
    -h|--help)
      echo "Usage: $0 [--staging] [--with-www] [--force-renewal]"
      echo ""
      echo "Environment variables (loaded from .env):"
      echo "  DOMAIN               Primary domain name (e.g. blinkist.example.com)"
      echo "  CERTBOT_EMAIL        Contact email for Let's Encrypt expiry notices"
      echo "  CERTBOT_STAGING      Set to 1 to test against Let's Encrypt staging CA"
      echo "  CERTBOT_INCLUDE_WWW  Set to 1 to also include www.\${DOMAIN}"
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $arg"
      exit 1
      ;;
  esac
done

echo "=================================================================="
echo " 🔒 Blinkist Clone - Let's Encrypt SSL/TLS Provisioning"
echo "=================================================================="

command -v docker >/dev/null 2>&1 || { echo >&2 "❌ Docker is required."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo >&2 "❌ Docker Compose v2 is required."; exit 1; }

if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "localhost" ] || [ "$DOMAIN" = "yourdomain.com" ]; then
  echo "❌ Please set a real production DOMAIN in .env (current: '${DOMAIN:-unset}')."
  exit 1
fi

if [ -z "$CERTBOT_EMAIL" ] || [ "$CERTBOT_EMAIL" = "admin@yourdomain.com" ]; then
  echo "❌ Please set a valid CERTBOT_EMAIL in .env for Let's Encrypt notifications."
  exit 1
fi

DOMAIN_ARGS=("-d" "$DOMAIN")
if [ "$INCLUDE_WWW" = "1" ]; then
  DOMAIN_ARGS+=("-d" "www.${DOMAIN}")
fi

STAGING_ARGS=()
if [ "$CERTBOT_STAGING" = "1" ]; then
  echo "ℹ️  Staging mode enabled (Let's Encrypt staging CA — untrusted test cert)."
  STAGING_ARGS+=("--staging")
fi

RENEW_ARGS=()
if [ "$FORCE_RENEWAL" = "1" ]; then
  RENEW_ARGS+=("--force-renewal")
fi

echo "🚀 [1/4] Ensuring Nginx gateway is running to serve ACME HTTP-01 challenges..."
docker compose up -d nginx

echo "⏳ [2/4] Requesting SSL/TLS certificate for ${DOMAIN}..."
docker compose run --rm --entrypoint certbot certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email "$CERTBOT_EMAIL" \
  --agree-tos \
  --no-eff-email \
  --rsa-key-size 4096 \
  "${STAGING_ARGS[@]}" \
  "${RENEW_ARGS[@]}" \
  "${DOMAIN_ARGS[@]}"

echo "🔄 [3/4] Restarting Nginx gateway to activate HTTPS (TLS 1.2/1.3 + HSTS)..."
docker compose restart nginx

echo "🛡️  [4/4] Starting Certbot 12-hour automated renewal sidecar..."
docker compose up -d certbot

echo "=================================================================="
echo " ✅ SSL/TLS Provisioned Successfully for https://${DOMAIN}!"
echo "    - HTTP -> HTTPS 301 Redirect: Enabled"
echo "    - TLS 1.2/1.3 + HSTS Preload: Enabled"
echo "    - Auto-Renewal Daemon:        Active (checks every 12h)"
echo "=================================================================="
