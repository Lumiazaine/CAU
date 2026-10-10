"""Transport-independent, sanitized errors and exact identifier validation."""
import re
from dataclasses import dataclass


@dataclass(frozen=True)
class Entry:
    form: str
    entry_id: str
    values: dict[str, str]


class TerminalError(ValueError):
    def __init__(self, code: str):
        self.code = code
        super().__init__(code)


def exact_name(value: str) -> bool:
    return (isinstance(value, str) and 0 < len(value) <= 200
            and value == value.strip() and not any(ord(c) < 32 for c in value))


def safe_field(value: str) -> bool:
    return exact_name(value) and not re.search(
        r"password|contrase(?:ñ|n)a|secret|token|cookie|authorization", value, re.IGNORECASE)
