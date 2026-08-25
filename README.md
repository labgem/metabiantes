# `metabiantes`

This tool allows to load the MetaCyc metabolic database knowledge base in a relational database.
Using the PathwayTools Lisp API, the script [./loader/metacyc-to-sql.lisp](./loader/metacyc-to-sql.lisp) generates a SQL dump of the MetaCyc database, using the schema defined in [./sql/create_schema.sql](./sql/create_schema.sql). This schema does not completely mirror the PathwayTools's Ocelot object database schema. Some information are not taken into account.


## Generate a SQL dump of the MetaCyc database

First, launch the pathway-tools Lisp API, in the the `./loader/` folder:

```console
pathway-tools -lisp 
```

Then, in the Lisp prompt, enter:

```lisp
(load "metacyc-to-sql")
(select-organism :org-id 'meta)
(write-to-file "dump.sql" (dump-all))
```
The dump will be written to a file named `dump.sql` in the current.

Alternatively, you wan use the wrapper shell script `metabiantes.sh` as follows

``` console
sh metabiantes.sh "dump.sql" "meta"
```

For the EcoCyc database dump using the same schema, you can replace `"meta"` by `"eco"`, or any other local BioCyc PGDB identifier.

## Create a SQLite database with this dump

Suppose we want to create a metabiantes SQLite database named `metabiantes.db`, we would proceed as follows:

1. Create the SQLite schema:
   ```console
   sqlite3 metabiantes.db < ../sql/create_schema.sql
   ```

2. Load the data from the metabiantes SQL dump: (see below for a faster recommended alternative command)
   ```console
   sqlite3 metabiantes.db < ./dump.sql
   ```

Here again, you will have to be patient, as loading data from the `dump.sql` file in the SQLite database takes a significant amount of time.
A faster way of creating this SQLite database is using the following SQLite `PRAGMA` instructions:
```sql
PRAGMA journal_mode=WAL;
PRAGMA cache_size=-50000; -- Negative = pages; 50000 × 4KB = 200MB
PRAGMA synchronous=NORMAL;
PRAGMA temp_store=MEMORY;
```
This will enable WAL mode and increase cache size. WAL mode reduces filesystem sync calls.  NORMAL synchronous mode reduces I/O waits, we do not need the 'FULL' synchronous mode, which ensures ACID compliance but is slower, as a single synchronous connection will be made on the SQLite database when we create it.

A wrapper script `loader/faster_sqlite3_load.sh` is available. It accepts two parameters: `database` and `dump` and loads the dump data into the SQLite3 database with the PRAGMA instructions mentioned above.
An example command line using this wrapper script is as follows:
```console
bash faster_sqlite3_load.sh metabiantes.db dump.sql
```

