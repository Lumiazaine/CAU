"""Composition root: only supported offline adapter can be constructed."""
from .application import RemedyApplication
from .config import load_policy
from .domain import TerminalError
from .synthetic import SyntheticReadAdapter


def build_application(path=None):
    policy = load_policy(path)
    if policy.adapter == "synthetic" and any(
        form != "SYN:Tickets" or not set(fields) <= {"summary", "status"}
        for form, fields in policy.forms.items()
    ):
        raise TerminalError("configuration_invalid")
    adapter = SyntheticReadAdapter() if policy.read_enabled else None
    return RemedyApplication(policy, adapter)
