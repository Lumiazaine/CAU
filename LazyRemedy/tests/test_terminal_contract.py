"""Read-port boundary tests; injected adapters below are explicitly SYNTHETIC spies."""
import asyncio

import pytest

from lazyremedy.terminal.application import RemedyApplication
from lazyremedy.terminal.config import TerminalPolicy
from lazyremedy.terminal.domain import Entry, TerminalError


@pytest.mark.parametrize("entry", [
    Entry("wrong", "SYN-0001", {"summary": "secret test data"}),
    Entry("SYN:Tickets", " SYN-0001", {"summary": "x"}),
    Entry("SYN:Tickets", "SYN-0001", {"summary": "x", "password": "TEST-SECRET"}),
    Entry("SYN:Tickets", "SYN-0001", {}),
    Entry("SYN:Tickets", "SYN-0001", {"summary": 123}),
    {"form": "SYN:Tickets", "entry_id": "SYN-0001", "values": {"summary": "x"}},
])
def test_adapter_response_outside_contract_fails_closed(entry):
    app, spy = approved_app()
    spy.search_result = [entry]
    with pytest.raises(TerminalError, match="adapter_contract_invalid"):
        asyncio.run(app.search("SYN:Tickets", {"status": "open"}, ["summary"], 1))
    spy.get_result = entry
    with pytest.raises(TerminalError, match="adapter_contract_invalid"):
        asyncio.run(app.get("SYN:Tickets", "SYN-0001", ["summary"]))



def test_get_rejects_mismatched_entry_id():
    app, spy = approved_app()
    spy.get_result = Entry("SYN:Tickets", "SYN-0002", {"summary": "x"})
    with pytest.raises(TerminalError, match="adapter_contract_invalid"):
        asyncio.run(app.get("SYN:Tickets", "SYN-0001", ["summary"]))


@pytest.mark.parametrize("entry_id", ["", " SYN-0001", "SYN-0001\n", True])
def test_get_rejects_malformed_id_without_normalization(entry_id):
    app, spy = approved_app()
    with pytest.raises(TerminalError, match="invalid_request"):
        asyncio.run(app.get("SYN:Tickets", entry_id, ["summary"]))
    assert spy.calls == []


def test_get_missing_entry_returns_sanitized_not_found():
    app, spy = approved_app()
    with pytest.raises(TerminalError, match="entry_not_found"):
        asyncio.run(app.get("SYN:Tickets", "SYN-9999", ["summary"]))


@pytest.mark.parametrize("rows", [
    None,
    [Entry("SYN:Tickets", "SYN-0001", {"summary": "x"})] * 2,
    [Entry("SYN:Tickets", f"SYN-{i}", {"summary": "x"}) for i in range(3)],
])
def test_search_adapter_batch_must_be_bounded_and_unique(rows):
    app, spy = approved_app()
    spy.search_result = rows
    with pytest.raises(TerminalError, match="adapter_contract_invalid"):
        asyncio.run(app.search("SYN:Tickets", {"status": "open"}, ["summary"], 1))


@pytest.mark.parametrize("operation", ["search", "get"])
def test_adapter_exception_is_sanitized(operation):
    app, spy = approved_app()

    async def failed(*args):
        raise RuntimeError("TEST-SECRET untrusted adapter diagnostic")

    setattr(spy, operation, failed)
    with pytest.raises(TerminalError, match="^adapter_failed$"):
        if operation == "search":
            asyncio.run(app.search("SYN:Tickets", {"status": "open"}, ["summary"]))
        else:
            asyncio.run(app.get("SYN:Tickets", "SYN-0001", ["summary"]))


class SyntheticSpy:
    def __init__(self):
        self.calls = []

    async def search(self, form, criteria, fields, limit):
        self.calls.append((form, criteria, fields, limit))
        return getattr(self, "search_result", [])

    async def get(self, form, entry_id, fields):
        self.calls.append((form, entry_id, fields))
        return getattr(self, "get_result", None)


def approved_app():
    spy = SyntheticSpy()
    policy = TerminalPolicy(adapter="synthetic", read_approved=True,
                            forms={"SYN:Tickets": ["summary", "status"]})
    return RemedyApplication(policy, spy), spy


@pytest.mark.parametrize("change", [
    {"form": "Unknown"}, {"form": " SYN:Tickets"}, {"criteria": {}},
    {"criteria": {"status": ""}}, {"criteria": {"status": "\n"}},
    {"criteria": {"password": "x"}}, {"criteria": {"status": True}},
    {"fields": []}, {"fields": ["summary", "summary"]}, {"fields": ["password"]},
    {"fields": "summary"}, {"limit": 0}, {"limit": 101}, {"limit": True},
])
def test_search_rejects_invalid_request_before_adapter(change):
    app, spy = approved_app()
    request = {"form": "SYN:Tickets", "criteria": {"status": "open"},
               "fields": ["summary"], "limit": 1}
    request.update(change)
    with pytest.raises(TerminalError, match="invalid_request"):
        asyncio.run(app.search(**request))
    assert spy.calls == []


def test_unapproved_read_never_reaches_adapter():
    spy = SyntheticSpy()
    app = RemedyApplication(TerminalPolicy(adapter="synthetic", read_approved=False,
                           forms={"SYN:Tickets": ["status"]}), spy)
    with pytest.raises(TerminalError, match="read_disabled"):
        asyncio.run(app.search("SYN:Tickets", {"status": "open"}, ["status"]))
    assert spy.calls == []
