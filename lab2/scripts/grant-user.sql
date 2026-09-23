\set ON_ERROR_STOP on

-- Run this file once as the postgres administrator.
-- The lab_user variable is supplied by scripts/setup.sh instructions.
SELECT format('CREATE ROLE %I LOGIN', :'lab_user')
WHERE NOT EXISTS (
  SELECT 1 FROM pg_roles WHERE rolname = :'lab_user'
) \gexec

GRANT CONNECT ON DATABASE northwind TO :"lab_user";

\connect northwind

GRANT USAGE, CREATE ON SCHEMA public TO :"lab_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"lab_user";
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO :"lab_user";

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"lab_user";
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO :"lab_user";

SELECT current_database() AS database,
       :'lab_user' AS configured_user,
       'ready' AS status;

