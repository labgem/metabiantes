"""
Chemical compound object
"""

from typing import List
from typing import Optional

from sqlalchemy import ForeignKey
from sqlalchemy import String
from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column
from sqlalchemy.orm import relationship

from .base import Base

class Compound(Base):
    __tablename__ = "compound"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(30))

    def __repr__(self) -> str:
        return f"Compound(id={self.id!r}, name={self.name!r})"
