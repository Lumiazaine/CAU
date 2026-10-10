"""Use cases shared by CLI and MCP; no transport or SDK imports."""


from .config import TerminalPolicy
from .ports import ReadPort
from .domain import Entry, TerminalError, exact_name, safe_field


class RemedyApplication:
    def __init__(self, policy: TerminalPolicy | None = None, adapter: ReadPort | None = None):
        self.policy = policy or TerminalPolicy()
        self.adapter = adapter

    def health(self) -> dict:
        return {"status": "offline" if self.policy.read_enabled else "blocked",
                "mode": self.policy.adapter, "live": False,
                "verified_scope": "offline", "read_enabled": self.policy.read_enabled,
                "write_enabled": False}

    def _read_guard(self, form: str, fields: list[str]) -> None:
        if not self.policy.read_enabled or self.adapter is None:
            raise TerminalError("read_disabled")
        allowed = self.policy.forms.get(form, []) if isinstance(form, str) else []
        if (not exact_name(form) or not allowed or not isinstance(fields, list)
                or not 1 <= len(fields) <= 50 or not all(map(safe_field, fields))
                or len(set(fields)) != len(fields) or not set(fields) <= set(allowed)):
            raise TerminalError("invalid_request")

    @staticmethod
    def _validate_entry(entry: Entry, form: str, fields: list[str]) -> None:
        if (not isinstance(entry, Entry) or entry.form != form or not exact_name(entry.entry_id)
                or not isinstance(entry.values, dict) or set(entry.values) != set(fields)
                or not all(isinstance(value, str) for value in entry.values.values())):
            raise TerminalError("adapter_contract_invalid")

    async def search(self, form: str, criteria: dict[str, str], fields: list[str],
                     limit: int = 50) -> dict:
        self._read_guard(form, fields)
        if (type(limit) is not int or not 1 <= limit <= 100
                or not isinstance(criteria, dict) or not 1 <= len(criteria) <= 50
                or any(k not in self.policy.forms[form] or not isinstance(v, str)
                       or not v.strip() or len(v) > 1000 or any(ord(c) < 32 for c in v)
                       for k, v in criteria.items())):
            raise TerminalError("invalid_request")
        assert self.adapter is not None  # established by _read_guard
        try:
            rows = await self.adapter.search(form, criteria, fields, limit + 1)
        except Exception:
            raise TerminalError("adapter_failed") from None
        if not isinstance(rows, list) or len(rows) > limit + 1:
            raise TerminalError("adapter_contract_invalid")
        for entry in rows:
            self._validate_entry(entry, form, fields)
        if len({entry.entry_id for entry in rows}) != len(rows):
            raise TerminalError("adapter_contract_invalid")
        selected = rows[:limit]
        return {"mode": self.policy.adapter, "live": False, "form": form,
                "entries": [{"entry_id": e.entry_id, "values": e.values} for e in selected],
                "returned_count": len(selected), "has_more": len(rows) > limit}

    async def get(self, form: str, entry_id: str, fields: list[str]) -> dict:
        self._read_guard(form, fields)
        if not exact_name(entry_id):
            raise TerminalError("invalid_request")
        assert self.adapter is not None
        try:
            entry = await self.adapter.get(form, entry_id, fields)
        except Exception:
            raise TerminalError("adapter_failed") from None
        if entry is None:
            raise TerminalError("entry_not_found")
        self._validate_entry(entry, form, fields)
        if entry.entry_id != entry_id:
            raise TerminalError("adapter_contract_invalid")
        return {"mode": self.policy.adapter, "live": False, "form": form,
                "entry_id": entry.entry_id, "values": entry.values}

    def capabilities(self) -> dict:
        tools = ["remedy_health", "remedy_capabilities"]
        if self.policy.read_enabled:
            tools += ["remedy_search", "remedy_get"]
        return {"mode": self.policy.adapter, "live": False, "verified_scope": "offline",
                "read_enabled": self.policy.read_enabled, "write_enabled": False,
                "tools": tools, "forms": self.policy.forms if self.policy.read_enabled else {},
                "max_limit": 100, "live_contract_verified": False}
