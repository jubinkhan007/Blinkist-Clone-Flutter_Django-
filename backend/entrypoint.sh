#!/bin/sh
set -e

# Wait for PostgreSQL database if DATABASE_URL contains postgres
python - << 'EOF'
import os, sys, time, socket
from urllib.parse import urlparse

db_url = os.environ.get("DATABASE_URL")
if db_url and "postgres" in db_url:
    try:
        parsed = urlparse(db_url)
        host = parsed.hostname or "localhost"
        port = parsed.port or 5432
        print(f"[*] Checking PostgreSQL readiness at {host}:{port}...", flush=True)
        for i in range(60):
            try:
                with socket.create_connection((host, port), timeout=2):
                    print("[+] PostgreSQL database is ready!", flush=True)
                    break
            except (socket.error, OSError):
                time.sleep(1)
        else:
            print("[-] Timed out waiting for PostgreSQL.", file=sys.stderr, flush=True)
            sys.exit(1)
    except Exception as exc:
        print(f"[!] Warning while checking database readiness: {exc}", flush=True)
EOF

# If running Django web server, automatically apply migrations and collect static assets
if [ "$1" = "gunicorn" ] || [ "$1" = "python" -a "$2" = "manage.py" -a "$3" = "runserver" ]; then
    echo "[*] Applying database migrations..."
    python manage.py migrate --noinput

    echo "[*] Collecting static files..."
    python manage.py collectstatic --noinput --clear || echo "[!] Static collection completed with warnings"
fi

exec "$@"
