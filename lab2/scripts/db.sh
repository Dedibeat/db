#!/usr/bin/env bash
set -Eeuo pipefail

DB_NAME="northwind"
DB_USER="${USER:-$(id -un)}"
DB_HOST="/var/run/postgresql"
DB_PORT="5432"

psql_lab() {
  psql -X -v ON_ERROR_STOP=1 \
    -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$@"
}

require_server() {
  if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" >/dev/null 2>&1; then
    echo "The system PostgreSQL server is not ready." >&2
    echo "Start it once with: sudo systemctl start postgresql" >&2
    exit 1
  fi
}

case "${1:-help}" in
  start)
    if pg_isready -h "$DB_HOST" -p "$DB_PORT" >/dev/null 2>&1; then
      echo "System PostgreSQL is already running."
    else
      echo "Run: sudo systemctl start postgresql" >&2
      exit 1
    fi
    ;;
  status)
    pg_isready -h "$DB_HOST" -p "$DB_PORT"
    ;;
  connect)
    require_server
    exec psql -X -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
    ;;
  check)
    require_server
    psql_lab --pset=footer=off --command="
      SELECT current_database() AS database,
             current_user AS username,
             version() AS server_version;
      SELECT 'categories' AS table_name, count(*) AS rows FROM categories
      UNION ALL SELECT 'customers', count(*) FROM customers
      UNION ALL SELECT 'employees', count(*) FROM employees
      UNION ALL SELECT 'order_details', count(*) FROM order_details
      UNION ALL SELECT 'orders', count(*) FROM orders
      UNION ALL SELECT 'products', count(*) FROM products
      ORDER BY table_name;"
    ;;
  help|--help|-h)
    echo "Usage: $0 {start|status|connect|check}"
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Usage: $0 {start|status|connect|check}" >&2
    exit 2
    ;;
esac

