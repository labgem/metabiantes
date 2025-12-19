"""
Reaction object model
"""
from typing import List
from typing import Optional

from sqlalchemy import ForeignKey
from sqlalchemy import String
from sqlalchemy import Float
from sqlalchemy import Boolean
from sqlalchemy import UUID
from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column
from sqlalchemy.orm import relationship
from sqlalchemy import PrimaryKeyConstraint

from .base import Base
from .compound import Compound


class Reaction(Base):
    __tablename__ = "reaction"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(30))
    left: Mapped[List[Compound]] = relationship(
        "ReactionReactant",
        uselist=True
    )
    right: Mapped[List[Compound]] = relationship(
        "ReactionReactant",
        uselist=True
    )
    spontaneous: Mapped[bool] = mapped_column(Boolean())

    def __repr__(self) -> str:
        return f"Reaction(id={self.id!r}, name={self.name!r})"

class ReactionReactant(Base):
    __tablename__ = 'reaction_reactant'

    reaction_id: Mapped[int] = mapped_column(UUID(as_uuid=True), ForeignKey('reaction.id'))
    compound_id: Mapped[int] = mapped_column(UUID(as_uuid=True), ForeignKey('compound.id'))
    __table_args__ = (
        PrimaryKeyConstraint('reaction_id', 'compound_id'),
    )
