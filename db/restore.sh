#!/bin/bash

echo "start bash";

while ! nc -z localhost 5432; do sleep 2; echo "check"; done;

sleep 1;
echo "start script";

PGPASSWORD=P@ssw0rd pg_restore --host=localhost --port=5432 --username=smaug --dbname=bingo --if-exists --clean /tmp/init_db.sql;

echo "base deployed, boss";

PGPASSWORD=P@ssw0rd psql --host=localhost --port=5432 --username=smaug --dbname=bingo -f /tmp/commands.sql

echo "base patched, boss";
