"""Read port: adapter contract, deliberately no create/update/delete operations."""
from typing import Protocol

from .domain import Entry


class ReadPort(Protocol):
    async def get(self, form: str, entry_id: str, fields: list[str]) -> Entry | None: ...

    async def search(self, form: str, criteria: dict[str, str], fields: list[str],
                     limit: int) -> list[Entry]: ...
