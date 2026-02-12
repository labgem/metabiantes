#!/usr/bin/env sh
# A wrapper script on pathway-tools and the metacyc-to-sql lisp script
# to export a PGDB as a metabiantes sql dump
#
# Usage:
# $ metabiantes.sh [FILE] [ORGANISM_ID]
# Example, to dump metacyc to dump.sql:
# $ metabiantes.sh dump.sql meta

file="${1:-dump.sql}"
org_id="${2:-meta}"

printf "dumping %s PGDB to file %s" "${org_id}" "${file}" >/dev/stderr

pathway-tools -lisp -eval "
              (progn
                   (load \"metacyc-to-sql\")
                   (select-organism :org-id '${org_id})
                   (write-to-file \"${file}\" (dump-all))
                   (exit)
              )"
