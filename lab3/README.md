# Database Lab 3: Temporary tables and UDFs

Бие даалт 10. The solution is in `23B1NUM1470_Дугаржанцан_Билгүүн_Биедаалт10.sql` and the report is the PDF with the same name.

## Environment

PostgreSQL 16.15 is installed as a portable copy (no admin rights, no Windows service):

| Item | Location |
|---|---|
| Binaries | `%LOCALAPPDATA%\Programs\PostgreSQL\16\bin` |
| Data directory | `%LOCALAPPDATA%\PostgreSQL\16\data` |
| Server log | `%LOCALAPPDATA%\PostgreSQL\16\server.log` |
| Connection | `localhost:5432`, database `northwind`, user `dedibeat`, no password |

The server only listens on `localhost` and uses trust authentication, so no password is needed. It does not start automatically after a reboot.

## Commands

Run these from the `lab3` folder:

| Command | Purpose |
|---|---|
| `scripts\db.cmd start` | Start PostgreSQL |
| `scripts\db.cmd stop` | Stop PostgreSQL |
| `scripts\db.cmd status` | Check whether it accepts connections |
| `scripts\db.cmd check` | Show login and Northwind row counts |
| `scripts\db.cmd connect` | Open `psql` |
| `scripts\db.cmd run` | Run the whole solution file with `ON_ERROR_STOP` |
| `python scripts\save_results.py` | Save every query result to `results\` (txt + csv) |
| `python scripts\build_report.py` | Regenerate screenshots and the PDF report |

The report figures are VS Code SQLTools screenshots: `report\img\ss1.png` … `ss26.png` follow the order of `results\txt\task01_1` … `task10_5`, and `ss27`–`ss30` are the error demos (Task 1 question, Task 6, Task 9 ×2). `build_report.py` renders only `ex10e.png` from psql, the full CTE plan that SQLTools truncates. `--no-shots` skips that step and only rebuilds the PDF.

## VS Code

Open the `lab3` folder in VS Code. The SQLTools connection **Lab 3 Northwind** is saved in `.vscode/settings.json`. When running a temp-table query in SQLTools, select the `CREATE TEMP TABLE` statement and the query together, because SQLTools may run separate executions on different connections.

## Notes

- psql on Windows cannot open the Cyrillic file name directly; `db.cmd run` runs an ASCII-named copy.
- Set `PGCLIENTENCODING=UTF8` when using `psql` yourself so Mongolian text is sent correctly.
- Task 9 changes `products` inside `BEGIN ... ROLLBACK`, so Northwind data stays unchanged.
