#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# Blinkist Clone - Incident Alerting & Webhook Test Utility
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Load environment configuration if available
if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env
fi

ALERTMANAGER_HOST="${ALERTMANAGER_HOST:-http://localhost:${ALERTMANAGER_PORT:-9093}}"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo "=================================================================="
echo " 🚨 Blinkist Clone - Alerting & Webhook Diagnostic Test"
echo "=================================================================="

# 1. Test Direct Slack Webhook
if [ -n "$SLACK_WEBHOOK_URL" ]; then
  echo "📡 Testing Slack Webhook ($SLACK_CHANNEL)..."
  SLACK_PAYLOAD=$(cat <<EOF
{
  "channel": "${SLACK_CHANNEL:-#alerts}",
  "icon_emoji": ":rotating_light:",
  "text": "🚨 *[FIRING:1] High5xxErrorRate (CRITICAL)*\n*Summary:* Test Alert: Elevated HTTP 5xx Server Error Rate\n*Service:* \`api\` | *Severity:* \`CRITICAL\`\n*Description:* This is a simulated test alert from the Blinkist APM test suite.\n*Timestamp:* \`${TIMESTAMP}\`"
}
EOF
)
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H 'Content-Type: application/json' --data "$SLACK_PAYLOAD" "$SLACK_WEBHOOK_URL" || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Slack alert successfully dispatched! (HTTP 200)"
  else
    echo "   ⚠️  Slack webhook returned HTTP $HTTP_CODE"
  fi
else
  echo "ℹ️  SLACK_WEBHOOK_URL is not set in .env. Skipping direct Slack test."
fi

# 2. Test Direct Discord Webhook
if [ -n "$DISCORD_WEBHOOK_URL" ]; then
  echo "📡 Testing Discord Webhook..."
  DISCORD_PAYLOAD=$(cat <<EOF
{
  "username": "Blinkist Alertmanager",
  "avatar_url": "https://img.icons8.com/color/96/bell.png",
  "embeds": [
    {
      "title": "🚨 [FIRING] HighApiLatencyP95 (WARNING)",
      "description": "Simulated Alert: API 95th Percentile Latency Exceeds 2.0s",
      "color": 15158332,
      "fields": [
        { "name": "Service", "value": "api", "inline": true },
        { "name": "Severity", "value": "warning", "inline": true },
        { "name": "Threshold", "value": "p95 > 2.0s", "inline": true },
        { "name": "Description", "value": "Simulated test alert dispatched from Blinkist monitoring automation.", "inline": false }
      ],
      "footer": { "text": "Blinkist APM Alerting • ${TIMESTAMP}" }
    }
  ]
}
EOF
)
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H 'Content-Type: application/json' --data "$DISCORD_PAYLOAD" "$DISCORD_WEBHOOK_URL" || echo "000")
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
    echo "   ✅ Discord alert successfully dispatched! (HTTP $HTTP_CODE)"
  else
    echo "   ⚠️  Discord webhook returned HTTP $HTTP_CODE"
  fi
else
  echo "ℹ️  DISCORD_WEBHOOK_URL is not set in .env. Skipping direct Discord test."
fi

# 3. Test Prometheus Alertmanager API
echo "🔍 Checking Prometheus Alertmanager at $ALERTMANAGER_HOST..."
ALERTMGR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$ALERTMANAGER_HOST/-/healthy" 2>/dev/null || echo "000")
if [ "$ALERTMGR_STATUS" = "200" ]; then
  echo "   ✅ Alertmanager is running and healthy!"
  echo "   🚀 Injecting simulated alert into Alertmanager queue..."

  TEST_ALERT=$(cat <<EOF
[
  {
    "labels": {
      "alertname": "High5xxErrorRate",
      "service": "api",
      "severity": "critical",
      "environment": "production"
    },
    "annotations": {
      "summary": "Simulated Spike in HTTP 5xx Server Errors",
      "description": "Simulated diagnostic test from scripts/test-alert.sh. Verifying Alertmanager pipeline routing.",
      "runbook_url": "https://github.com/jubinkhan007/Blinkist-Clone-Flutter_Django-#troubleshooting"
    },
    "startsAt": "${TIMESTAMP}"
  }
]
EOF
)
  INJECT_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H 'Content-Type: application/json' --data "$TEST_ALERT" "$ALERTMANAGER_HOST/api/v2/alerts" || echo "000")
  if [ "$INJECT_CODE" = "200" ]; then
    echo "   ✅ Alert injected into Alertmanager successfully! Routing to configured webhook channels."
  else
    echo "   ⚠️  Alert injection returned HTTP $INJECT_CODE"
  fi
else
  echo "   ℹ️  Alertmanager container is not currently accessible at $ALERTMANAGER_HOST (start with docker compose up -d alertmanager)."
fi

echo "=================================================================="
echo "🎉 Alerting & Webhook check completed."
echo "=================================================================="
