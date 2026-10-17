# Lab 4 database helper for the portable PostgreSQL 16 install (no admin rights needed).
# Usage: scripts\db.cmd {start|stop|status|init-pubs|check|connect|run} [pubs|northwind]
param(
    [ValidateSet('start', 'stop', 'status', 'init-pubs', 'check', 'connect', 'run', 'help')]
    [string]$Command = 'help',
    [ValidateSet('pubs', 'northwind')]
    [string]$Database = 'pubs'
)

$ErrorActionPreference = 'Stop'

$PgBin  = Join-Path $env:LOCALAPPDATA 'Programs\PostgreSQL\16\bin'
$PgRoot = Join-Path $env:LOCALAPPDATA 'PostgreSQL\16'
$PgData = Join-Path $PgRoot 'data'
$PgLog  = Join-Path $PgRoot 'server.log'

$env:PGHOST           = 'localhost'
$env:PGPORT           = '5432'
$env:PGUSER           = 'dedibeat'
$env:PGDATABASE       = $Database
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
    'init-pubs' {
        # dedibeat has no CREATEDB right, so the empty database is created by the
        # postgres superuser (trust authentication on localhost) and owned by dedibeat.
        Assert-Server
        & $Psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 `
            -c 'DROP DATABASE IF EXISTS pubs' `
            -c "CREATE DATABASE pubs OWNER dedibeat ENCODING 'UTF8' TEMPLATE template0"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $Psql -X -q -d pubs -v ON_ERROR_STOP=1 -f (Join-Path $LabDir 'pubs_postgres.sql')
        exit $LASTEXITCODE
    }
    'check' {
        Assert-Server
        & $Psql -X -d pubs --pset=footer=off -c @"
SELECT current_database() AS database, current_user AS username, version() AS server_version;
SELECT 'authors' AS table_name, count(*) AS rows FROM authors
UNION ALL SELECT 'discounts', count(*) FROM discounts
UNION ALL SELECT 'employee', count(*) FROM employee
UNION ALL SELECT 'jobs', count(*) FROM jobs
UNION ALL SELECT 'pub_info', count(*) FROM pub_info
UNION ALL SELECT 'publishers', count(*) FROM publishers
UNION ALL SELECT 'roysched', count(*) FROM roysched
UNION ALL SELECT 'sales', count(*) FROM sales
UNION ALL SELECT 'stores', count(*) FROM stores
UNION ALL SELECT 'titleauthor', count(*) FROM titleauthor
UNION ALL SELECT 'titles', count(*) FROM titles
ORDER BY table_name;
"@
    }
    'connect' {
        Assert-Server
        chcp 65001 | Out-Null
        & $Psql -X
    }
    'run' {
        # Run pubs_procedures.sql or northwind_procedures.sql on its own database.
        Assert-Server
        & $Psql -X -v ON_ERROR_STOP=1 -f (Join-Path $LabDir "$($Database)_procedures.sql")
        exit $LASTEXITCODE
    }
    default {
        Write-Host 'Usage: scripts\db.cmd {start|stop|status|init-pubs|check|connect|run} [pubs|northwind]'
    }
}
