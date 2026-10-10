"""Explicit terminal-only policy. No environment or legacy settings inheritance."""
import json
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from .domain import TerminalError, exact_name, safe_field


class TerminalPolicy(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", frozen=True)
    adapter: Literal["blocked", "synthetic"] = "blocked"
    read_approved: bool = False
    forms: dict[str, list[str]] = Field(default_factory=dict)

    @field_validator("forms")
    @classmethod
    def validate_forms(cls, forms):
        if len(forms) > 100:
            raise ValueError("invalid_forms")
        for form, fields in forms.items():
            if (not exact_name(form) or not 1 <= len(fields) <= 50
                    or len(set(fields)) != len(fields) or not all(map(safe_field, fields))):
                raise ValueError("invalid_forms")
        return forms

    @property
    def read_enabled(self) -> bool:
        return self.adapter == "synthetic" and self.read_approved and bool(self.forms)


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate_key")
        result[key] = value
    return result


def load_policy(path: str | None = None) -> TerminalPolicy:
    if path is None:
        return TerminalPolicy()
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"), object_pairs_hook=_unique_object)
        return TerminalPolicy.model_validate(data)
    except (OSError, ValueError):
        raise TerminalError("configuration_invalid") from None
