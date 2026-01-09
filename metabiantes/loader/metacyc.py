"""
MetaCyc data loader
"""
import logging
import os

import pythoncyc
import aiosql
import tqdm

from .. import model

logger = logging.getLogger("metabiantes:loader:metacyc")

def remove_pipes(identifier: str) -> str:
    return identifier.replace("|", "")

class MetaCycLoader:
    """
    A loader for MetaCyc PGDB data into the Metabiantes SQLite database
    """

    def __init__(self, connection):
        self.schema_queries = aiosql.from_path(os.path.join(__file__, "../sql/create_schema.sql"))
        self.queries = aiosql.from_path(os.path.join(__file__, "../sql/queries.sql"))
        self.pgdb: pythoncyc.PGDB = pythoncyc.select_organism("meta")
        self.load_all()

    def load_all(self):
        self.load_all_compounds()
