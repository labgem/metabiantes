"""
MetaCyc data loader
"""
from tkinter import W
import logging

import pythoncyc
import sqlalchemy
from sqlalchemy.orm import Session, scoped_session, sessionmaker
import tqdm

from .. import model

logger = logging.getLogger("metabiantes:loader:metacyc")

def remove_pipes(identifier: str) -> str:
    return identifier.replace("|", "")

class MetaCycLoader:
    """
    A loader for MetaCyc PGDB data into the Metabiantes ORM data model
    """

    def __init__(self, engine: sqlalchemy.Engine):
        self.engine = engine
        self.pgdb: pythoncyc.PGDB = pythoncyc.select_organism("meta")
        self.session = scoped_session(sessionmaker())
        self.session.configure(bind=self.engine)
        self.load_all()

    def load_all(self):
        self.load_reactions()

    def is_spontaneous(self, reaction: str) -> bool:
        """
        Return True if and only if reaction spontaneous_p predicate is True, otherwise returns False.
        """
        return self.pgdb[reaction].spontaneous_p is not None and self.pgdb[reaction].spontaneous_p


    def load_reactions(self):
        logging.info("Loading MetaCyc reactions")
        objects = []
        for reaction in tqdm.tqdm(self.pgdb.all_reactions()):
            reaction_name = remove_pipes(reaction)
            reaction_spontaneous = self.is_spontaneous(reaction)
            reaction_object = model.Reaction(name=reaction_name, spontaneous=reaction_spontaneous)
            objects.append(reaction_object)
        self.session.bulk_save_objects(objects)
        self.session.commit()
