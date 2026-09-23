# Database Lab 2 User Manual

Your Northwind installation is correct: it contains 91 customers, 830 orders, 77 products, and 2,155 order-detail rows. This workspace uses that existing PostgreSQL 16 database on the standard local server. It includes a one-time permission setup, VS Code SQLTools configuration, connection checks, and a structured `lab.sql` working file.

## One-time setup

Northwind is currently owned by the PostgreSQL administrator. Give your normal Linux user permission to use it so you do not need `sudo` for every query:

```bash
sudo -u postgres psql -v lab_user="dedibeat" -f scripts/grant-user.sql
make setup
code .
```

The first command asks for your Linux sudo password, creates a PostgreSQL login named `dedibeat`, and grants only the database permissions needed for this lab. It does not set or store a database password. Local connections use Ubuntu's peer authentication, which verifies that the operating-system user is also `dedibeat`.

`make setup` checks the server, verifies the Northwind row counts, and installs the VS Code SQLTools extensions if either is missing.

## Connect in VS Code

1. Click the SQLTools database icon in the left sidebar.
2. Under **Course databases**, click **Lab 2 Northwind** and choose **Connect**.
3. Open `lab.sql`.
4. Highlight one statement and run **SQLTools Run Selected Query** from the Command Palette (`Ctrl+Shift+P`).

The saved connection uses the local Unix socket `/var/run/postgresql`, database `northwind`, and user `dedibeat`. No password is needed, and the database is not exposed over a new network port.

## Normal workflow

At the beginning of a lab session:

```bash
make start
make check
```

`make start` confirms PostgreSQL is running. Ubuntu already enables it at boot. If it is ever stopped, run `sudo systemctl start postgresql` once.

Write your answers in `lab.sql`. First test the inner `SELECT`; then create the view; then run the required final query against that view. Save the file frequently. PostgreSQL saves successful database changes, but the SQL file is the reproducible copy you should submit and keep.

## Useful commands

| Command | Purpose |
|---|---|
| `make setup` | Verify permissions, data, and VS Code extensions |
| `make start` | Confirm the system PostgreSQL server is running |
| `make status` | Show whether PostgreSQL accepts connections |
| `make check` | Test your login and show key Northwind row counts |
| `make connect` | Open the `psql` terminal client as `dedibeat` |

## SQLTools basics

- **Run one statement:** place the cursor in it, or highlight it, then run **SQLTools Run Selected Query**.
- **See tables:** expand `Lab 2 Northwind` → `northwind` → `public` → `Tables`.
- **See your views:** expand `public` → `Views` or `Materialized Views`, then refresh the explorer.
- **Read errors from the bottom up:** PostgreSQL usually reports the exact line and a useful hint.
- **End statements with `;`:** this tells PostgreSQL where a statement finishes.
- **Use `LIMIT` while exploring:** it prevents an enormous result grid.

## psql terminal basics

Run `make connect`. At the `northwind=>` prompt, SQL works normally. These backslash commands are `psql` shortcuts, not SQL:

```text
\dt                  list tables
\dv                  list ordinary views
\dm                  list materialized views
\d products          describe one table
\d+ v_order_totals   describe one view in detail
\q                   exit psql
```

Run your entire saved file with:

```bash
psql -X -h /var/run/postgresql -U dedibeat -d northwind -f lab.sql
```

During development, SQLTools is usually easier because you can highlight and run one statement at a time.

## Assignment concepts

- **View (`харагдац`):** a saved query. Selecting from it runs the underlying query.
- **Materialized view:** stored query results. Reading is fast, but results update only after `REFRESH MATERIALIZED VIEW`.
- **CTE:** a named temporary result introduced by `WITH`; a recursive CTE can walk the employee-manager hierarchy.
- **Window function:** calculates across related rows without collapsing them. This lab uses `RANK`, `DENSE_RANK`, and `LAG`.
- **Conditional aggregate:** typically `SUM(CASE WHEN ... THEN ... ELSE 0 END)`, used for the pivot.
- **`WITH CHECK OPTION`:** rejects inserts or updates that would make a row disappear from the view.

For each numbered task:

1. Write and run the inner `SELECT`.
2. Check a few result rows and totals.
3. Wrap it in `CREATE OR REPLACE VIEW view_name AS ...`.
4. Run the required final query against the view.
5. Keep the view definition and final query together in `lab.sql`.

For money calculations, Northwind stores some values as floating-point numbers. Cast to `numeric` before rounding:

```sql
ROUND((some_expression)::numeric, 2)
```

For task 5, run the intentionally failing update by itself. That expected error should not prevent the rest of your file from running. For task 6, `REFRESH MATERIALIZED VIEW CONCURRENTLY` requires a unique index and a materialized view that has already been populated once.

## Safe experimentation

Before trying inserts or updates, use a transaction when you do not want to keep the change:

```sql
BEGIN;

-- Try INSERT or UPDATE statements here.

ROLLBACK; -- undo everything since BEGIN
-- Use COMMIT instead only when you want to keep it.
```

`DROP VIEW` removes a view but not the source table data. `DROP TABLE`, `DELETE`, and `TRUNCATE` change or remove source data, so avoid them unless you deliberately need them.

## Troubleshooting

**`role "dedibeat" does not exist`**

Run the one-time administrator command at the top of this manual, then `make setup`.

**SQLTools says connection refused**

Run `make status`. If PostgreSQL is stopped, run `sudo systemctl start postgresql`, then reconnect.

**SQLTools asks for a password**

Make sure you opened this folder as the VS Code workspace and selected **Lab 2 Northwind**. Its server must be `/var/run/postgresql`, not `127.0.0.1`.

**A view already exists**

Prefer `CREATE OR REPLACE VIEW` while developing. If you changed its column names or types, remove only that view and recreate it:

```sql
DROP VIEW IF EXISTS view_name;
```

**One error stops the whole SQL file**

Run statements individually in SQLTools, especially the deliberately failing `WITH CHECK OPTION` example.

**You accidentally changed Northwind source data**

Stop and keep your `lab.sql`. Since the source database is owned by `postgres`, the cleanest recovery is to re-import the original Northwind seed as the administrator. Do not drop the database unless your saved SQL work is backed up.

## Environment summary

- Ubuntu 24.04
- PostgreSQL 16.15, active and enabled at boot
- Database: `northwind` on the local Unix socket
- Lab user: `dedibeat`
- GUI: VS Code with SQLTools 0.28.6 and PostgreSQL driver 0.5.8
- Dataset verified: 91 customers, 830 orders, 77 products, 2,155 order details

