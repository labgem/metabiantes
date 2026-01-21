#!/usr/bin/bash 
rm test.db
sqlite3 test.db < ../sql/create_schema.sql
sqlite3 test.db < dump.sql
