import os
import sqlalchemy
from sqlalchemy.orm import sessionmaker

import metabiantes
import metabiantes.loader.metacyc

from metabiantes.model import Pathway
from metabiantes.model import Reaction
from metabiantes.model import Compound
from metabiantes.model import Base

def main():
    engine = sqlalchemy.create_engine("sqlite+pysqlite:///metabiantes.db", echo=True)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    metacyc_loader = metabiantes.loader.metacyc.MetaCycLoader(engine=engine)


if __name__ == "__main__":
    main()
