#!/bin/sh
set -eu

DOMAIN="${DOMAIN:-localhost}"
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
CERT_FILE="${CERT_DIR}/fullchain.pem"
KEY_FILE="${CERT_DIR}/privkey.pem"
SSL_TEMPLATE="/etc/nginx/nginx.ssl.conf.template"
HTTP_CONF="/etc/nginx/nginx.http.conf"
ACTIVE_CONF="/etc/nginx/nginx.conf"

render_config() {
  if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "localhost" ] && [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    echo "🔒 SSL certificates detected for ${DOMAIN} — activating hardened HTTPS (TLS 1.2/1.3 + HSTS + HTTP->HTTPS redirect)."
    envsubst '${DOMAIN}' < "$SSL_TEMPLATE" > "$ACTIVE_CONF"
  else
    echo "ℹ️  No Let's Encrypt certificate found at ${CERT_FILE} — starting in hardened HTTP mode (ACME challenge ready)."
    cp "$HTTP_CONF" "$ACTIVE_CONF"
  fi
}

render_config
nginx -t

# Background zero-downtime certificate reloader (checks every 6 hours)
(
  while :; do
    sleep 6h
    echo "🔄 Checking SSL certificates & reloading Nginx configuration..."
    render_config
    if nginx -t >/dev/null 2>&1; then
      nginx -s reload
      echo "✅ Nginx reloaded cleanly."
    else
      echo "⚠️  Nginx config test failed during scheduled reload; keeping active worker config."
    fi
  done
) &

exec nginx -g "daemon off;"
