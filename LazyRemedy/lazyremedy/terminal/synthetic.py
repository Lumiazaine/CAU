"""Offline in-memory adapter. These records are invented TEST DATA, not live results."""
from .domain import Entry


class SyntheticReadAdapter:
    def __init__(self):
        self.entries = [
            Entry("SYN:Tickets", "SYN-0001", {"summary": "Prueba sintética uno", "status": "open"}),
            Entry("SYN:Tickets", "SYN-0002", {"summary": "Prueba sintética dos", "status": "open"}),
        ]

    async def get(self, form, entry_id, fields):
        entry = next((e for e in self.entries if e.form == form and e.entry_id == entry_id), None)
        return Entry(form, entry_id, {f: entry.values[f] for f in fields}) if entry else None

    async def search(self, form, criteria, fields, limit):
        return [Entry(e.form, e.entry_id, {f: e.values[f] for f in fields})
                for e in self.entries if e.form == form
                and all(e.values.get(k) == v for k, v in criteria.items())][:limit]
