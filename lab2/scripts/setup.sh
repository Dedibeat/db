#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_USER="${USER:-$(id -un)}"

for required in psql pg_isready code; do
  command -v "$required" >/dev/null 2>&1 || {
    echo "Required command not found: $required" >&2
    exit 1
  }
done

if ! pg_isready -h /var/run/postgresql -p 5432 >/dev/null 2>&1; then
  echo "PostgreSQL is installed but not running." >&2
  echo "Run: sudo systemctl start postgresql" >&2
  exit 1
fi

if ! psql -X -h /var/run/postgresql -p 5432 -U "$DB_USER" -d northwind \
  -tAc "SELECT 1" >/dev/null 2>&1; then
  echo "Your PostgreSQL role needs one-time setup. Run this command:" >&2
  echo >&2
  echo "  sudo -u postgres psql -v lab_user=\"$DB_USER\" -f \"$ROOT_DIR/scripts/grant-user.sql\"" >&2
  echo >&2
  echo "Then run: make setup" >&2
  exit 1
fi

echo "Checking Northwind data and permissions..."
"$ROOT_DIR/scripts/db.sh" check

echo "Checking VS Code database extensions..."
for extension in mtxr.sqltools mtxr.sqltools-driver-pg; do
  if ! code --list-extensions | grep -Fxiq "$extension"; then
    code --install-extension "$extension"
  fi
done

echo
echo "Setup complete. Run 'code .' and open README.md."

