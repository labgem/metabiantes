# `metabiantes`

This tool allows to load the MetaCyc metabolic database knowledge base in a relational database.
Using the PathwayTools Lisp API, the script [./metabiantes/loader/metacyc-to-sql.lisp](./metabiantes/loader/metacyc-to-sql.lisp) generates a SQL dump of the MetaCyc database, using the schema defined in [./metabiantes/sql/create_schema.sql](./metabiantes/sql/create_schema.sql). This schema does not completely mirror the PathwayTools's Ocelot object database schema. Some information are not taken into account (yet).


## Generate a SQL dump of the MetaCyc database

First, launch the pathway-tools Lisp API, in the the `./metabiantes/loader/` folder:

```console
pathway-tools -lisp 
```

Then, in the Lisp prompt, enter:

```lisp
(load "metacyc-to-sql")
(selet-organism :org-id 'meta)
(write-to-file "dump.sql" (dump-all))
```
The dump will be written to a file named `dump.sql` in the current.

Alternatively, you wan use the wrapper shell script `metabiantes.sh` as follows

``` console
sh metabiantes.sh "dump.sql" "meta"
```

For the EcoCyc database dump using the same schema, you can replace `"meta"` by `"eco"`.



## Create a PostgreSQL database with this dump

```console
sudo -u postgres psql
```

```sql
CREATE USER <user> WITH PASSWORD '<secret>';
CREATE DATABASE metabiantes OWNER <user>;
```

We consider still being in `./metabiantes/loader` directory.
Start by initializing the database schema. Note the filename of the schema used here: `create_schema_pg.sql`, specifically tuned for PostgreSQL SQL dialect.
```console
psql -U <user> -d metabiantes < ../sql/create_schema_pg.sql
```
Then, load the data from the SQL dump.

```console
psql -U <user> -d metabiantes < ./dump.sql
```

