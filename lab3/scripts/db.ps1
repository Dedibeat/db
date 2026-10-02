# Lab 3 database helper for the portable PostgreSQL 16 install (no admin rights needed).
# Usage: scripts\db.cmd {start|stop|status|connect|check|run}
param(
    [ValidateSet('start', 'stop', 'status', 'connect', 'check', 'run', 'help')]
    [string]$Command = 'help'
)

$ErrorActionPreference = 'Stop'

$PgBin  = Join-Path $env:LOCALAPPDATA 'Programs\PostgreSQL\16\bin'
$PgRoot = Join-Path $env:LOCALAPPDATA 'PostgreSQL\16'
$PgData = Join-Path $PgRoot 'data'
$PgLog  = Join-Path $PgRoot 'server.log'

$env:PGHOST           = 'localhost'
$env:PGPORT           = '5432'
$env:PGUSER           = 'dedibeat'
$env:PGDATABASE       = 'northwind'
$env:PGCLIENTENCODING = 'UTF8'

$LabDir  = Split-Path $PSScriptRoot -Parent
$Psql    = Join-Path $PgBin 'psql.exe'
$PgCtl   = Join-Path $PgBin 'pg_ctl.exe'
$IsReady = Join-Path $PgBin 'pg_isready.exe'

function Test-Server {
    & $IsReady -q
    return $LASTEXITCODE -eq 0
}

function Assert-Server {
    if (-not (Test-Server)) {
        Write-Error 'PostgreSQL is not running. Run: scripts\db.cmd start'
    }
}

switch ($Command) {
    'start' {
        if (Test-Server) {
            Write-Host 'PostgreSQL is already running.'
        } else {
            & $PgCtl -D $PgData -l $PgLog -w start | Out-Null
            & $IsReady
        }
    }
    'stop' {
        & $PgCtl -D $PgData -m fast stop
    }
    'status' {
        & $IsReady
    }
    'connect' {
        Assert-Server
        chcp 65001 | Out-Null
        & $Psql -X
    }
    'check' {
        Assert-Server
        & $Psql -X --pset=footer=off -c @"
SELECT current_database() AS database, current_user AS username, version() AS server_version;
SELECT 'categories' AS table_name, count(*) AS rows FROM categories
UNION ALL SELECT 'customers', count(*) FROM customers
UNION ALL SELECT 'employees', count(*) FROM employees
UNION ALL SELECT 'order_details', count(*) FROM order_details
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'shippers', count(*) FROM shippers
ORDER BY table_name;
"@
    }
    'run' {
        # psql on Windows cannot open the Cyrillic file name directly, so run an ASCII-named copy.
        Assert-Server
        $SqlFile = Get-ChildItem $LabDir -Filter '23B1NUM1470_*.sql' | Select-Object -First 1
        $Copy = Join-Path $env:TEMP 'lab3_solution.sql'
        Copy-Item $SqlFile.FullName $Copy -Force
        & $Psql -X -v ON_ERROR_STOP=1 -f $Copy
        exit $LASTEXITCODE
    }
    default {
        Write-Host 'Usage: scripts\db.cmd {start|stop|status|connect|check|run}'
    }
}
