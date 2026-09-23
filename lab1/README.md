# Database Lab 1: CTEs

This folder contains the PostgreSQL version of the six CTE exercises. It uses the same local PostgreSQL 16 Northwind database as Lab 2.

## Database setup

The PostgreSQL setup is shared with Lab 2. From this folder, run:

```bash
make setup
make check
```

`make setup` checks the local database and SQLTools extensions. If the `dedibeat` PostgreSQL role has not been created yet, use the one-time command in [Lab 2's README](../lab2/README.md#one-time-setup). The VS Code connection for Lab 1 is saved in `.vscode/settings.json`.

Run the complete solution in the terminal with:

```bash
make connect
```

Then, at the `northwind=>` prompt:

```text
\i cte_lab_solution.sql
```

Or open `cte_lab_solution.sql` in VS Code, select a query, and run **SQLTools Run Selected Query**.

## SQL Server to PostgreSQL notes

- Table and column identifiers use the lowercase `snake_case` names in the Lab 2 Northwind database.
- The recursive exercise uses PostgreSQL's `WITH RECURSIVE`; SQL Server's `OPTION (MAXRECURSION ...)` clause is not used.
- Numeric totals are cast to `numeric` before rounding to two decimal places.
