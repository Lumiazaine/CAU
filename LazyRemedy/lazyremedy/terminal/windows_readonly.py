"""Explicit opt-in read-only incident command; Windows dependencies are lazy."""
import json
import ntpath
import re
import unicodedata
from pathlib import Path

from .domain import TerminalError, exact_name, safe_field


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate key")
        result[key] = value
    return result


def _integer(value, maximum=2147483647):
    return type(value) is int and 0 < value <= maximum


def _numeric_id(value):
    return isinstance(value, str) and re.fullmatch(r"[1-9][0-9]{0,29}", value) is not None


def _safe_label(label):
    if not safe_field(label):
        return False
    # Normalize a comparison key only; preserve labels, IDs and values verbatim.
    normalized = unicodedata.normalize("NFKD", unicodedata.normalize("NFKC", label).casefold())
    normalized = "".join(char for char in normalized
                         if unicodedata.category(char) not in {"Mn", "Mc", "Me", "Cf"})
    compact = "".join(char for char in normalized if char.isalnum())
    # Reuse the complete existing denylist after normalization as well.
    if not safe_field(compact):
        return False
    return not (re.search(
        r"credential|credencial|password|passwd|pwd|contrasen|apikey|privatekey|accesskey|clave|"
        r"secret|token|authentication|authorization|autentic|autoriz|authcode|authkey|"
        r"verificationcode|codigodeverificacion|otp", compact)
        or compact in {"auth", "pin", "key", "keys"}
        or re.search(r"(?:^|[\W_])(?:auth|pin)(?:$|[\W_])", normalized))


def _field(spec, identity=False):
    keys = {"id", "label", "prefix", "digits"} if identity else {"id", "label"}
    if not isinstance(spec, dict) or set(spec) != keys:
        return False
    if not _integer(spec["id"]) or not _safe_label(spec["label"]):
        return False
    return not identity or (isinstance(spec["prefix"], str)
        and re.fullmatch(r"[A-Z][A-Z0-9_-]{0,29}", spec["prefix"]) is not None
        and _integer(spec["digits"], 30))


def _load_policy(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=_unique_object)
        keys = {"enabled", "read_only", "expected_host", "expected_user", "expected_session_id",
                "client_executable", "typelib_guid", "server", "form", "expected_auth_user",
                "incident_field", "approved_incident_ids", "fields"}
        if not isinstance(data, dict) or set(data) != keys:
            raise ValueError("schema")
        if data["enabled"] is not True or data["read_only"] is not True:
            raise ValueError("approval")
        for key in ("expected_host", "expected_user", "server", "form", "expected_auth_user"):
            if not exact_name(data[key]):
                raise ValueError("name")
        executable = data["client_executable"]
        if (not exact_name(executable) or not ntpath.isabs(executable)
                or not re.match(r"^[A-Za-z]:\\", executable)
                or ntpath.basename(executable).lower() != "aruser.exe"):
            raise ValueError("executable")
        if not _integer(data["expected_session_id"]):
            raise ValueError("session")
        if not isinstance(data["typelib_guid"], str) or re.fullmatch(
                r"\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}",
                data["typelib_guid"]) is None:
            raise ValueError("guid")
        if not _field(data["incident_field"], True):
            raise ValueError("identity")
        approved = data["approved_incident_ids"]
        if (not isinstance(approved, list) or not approved
                or any(not _numeric_id(item) or len(item) > data["incident_field"]["digits"] for item in approved)
                or len(set(approved)) != len(approved)):
            raise ValueError("allowlist")
        fields = data["fields"]
        if not isinstance(fields, list) or not fields or any(not _field(item) for item in fields):
            raise ValueError("fields")
        if (len({item["id"] for item in fields}) != len(fields)
                or len({item["label"] for item in fields}) != len(fields)):
            raise ValueError("duplicate fields")
        return data
    except (OSError, ValueError, TypeError, KeyError, RecursionError):
        raise TerminalError("configuration_invalid") from None


def _verify_context(policy, context):
    if (context["host"] != policy["expected_host"]
            or context["user"] != policy["expected_user"]
            or not _integer(context["session_id"])
            or context["session_id"] != policy["expected_session_id"]):
        raise TerminalError("interactive_session_required")
    clients = context["clients"]
    if len(clients) != 1:
        raise TerminalError("client_ownership_unverified")
    client = clients[0]
    if (client["sid"] != context["sid"] or client["logon_id"] != context["logon_id"]
            or client["session_id"] != context["session_id"]
            or ntpath.normcase(client["executable"]) != ntpath.normcase(policy["client_executable"])
            or client["visible_gui"] is not True or not _integer(client["pid"])):
        raise TerminalError("client_ownership_unverified")
    return client["pid"]


def _inspect_windows():
    """Read process/token metadata only; never launch a process or open its memory."""
    import ctypes
    from ctypes import wintypes as w
    import win32api
    import win32gui
    import win32process
    import win32security

    class ProcessEntry(ctypes.Structure):
        _fields_ = [("dwSize", w.DWORD), ("cntUsage", w.DWORD),
                    ("th32ProcessID", w.DWORD), ("th32DefaultHeapID", ctypes.c_size_t),
                    ("th32ModuleID", w.DWORD), ("cntThreads", w.DWORD),
                    ("th32ParentProcessID", w.DWORD), ("pcPriClassBase", w.LONG),
                    ("dwFlags", w.DWORD), ("szExeFile", w.WCHAR * 260)]

    api = ctypes.WinDLL("kernel32", use_last_error=True)
    signatures = {
        "GetCurrentProcess": ([], w.HANDLE), "GetCurrentProcessId": ([], w.DWORD),
        "ProcessIdToSessionId": ([w.DWORD, ctypes.POINTER(w.DWORD)], w.BOOL),
        "CreateToolhelp32Snapshot": ([w.DWORD, w.DWORD], w.HANDLE),
        "Process32FirstW": ([w.HANDLE, ctypes.POINTER(ProcessEntry)], w.BOOL),
        "Process32NextW": ([w.HANDLE, ctypes.POINTER(ProcessEntry)], w.BOOL),
        "OpenProcess": ([w.DWORD, w.BOOL, w.DWORD], w.HANDLE),
        "QueryFullProcessImageNameW": ([w.HANDLE, w.DWORD, w.LPWSTR, ctypes.POINTER(w.DWORD)], w.BOOL),
        "CloseHandle": ([w.HANDLE], w.BOOL),
    }
    for name, (args, result) in signatures.items():
        function = getattr(api, name)
        function.argtypes, function.restype = args, result

    def session_id(pid):
        value = w.DWORD()
        if not api.ProcessIdToSessionId(pid, ctypes.byref(value)):
            raise TerminalError("client_ownership_unverified")
        return value.value

    def token_metadata(handle):
        token = win32security.OpenProcessToken(handle, 0x0008)  # TOKEN_QUERY only.
        try:
            sid = win32security.GetTokenInformation(token, win32security.TokenUser)[0]
            return {"sid": win32security.ConvertSidToStringSid(sid),
                    "session_id": win32security.GetTokenInformation(token, win32security.TokenSessionId),
                    "logon_id": win32security.GetTokenInformation(token, win32security.TokenStatistics)["AuthenticationId"]}
        finally:
            token.Close()

    caller = token_metadata(api.GetCurrentProcess())
    if caller["session_id"] <= 0 or caller["session_id"] != session_id(api.GetCurrentProcessId()):
        raise TerminalError("interactive_session_required")
    visible = set()
    def window(hwnd, _):
        if win32gui.IsWindowVisible(hwnd):
            visible.add(win32process.GetWindowThreadProcessId(hwnd)[1])
    win32gui.EnumWindows(window, None)
    clients = []
    handle = api.CreateToolhelp32Snapshot(0x00000002, 0)  # TH32CS_SNAPPROCESS metadata.
    if handle in (None, ctypes.c_void_p(-1).value):
        raise TerminalError("client_ownership_unverified")
    try:
        entry = ProcessEntry()
        entry.dwSize = ctypes.sizeof(entry)
        found = api.Process32FirstW(handle, ctypes.byref(entry))
        while found:
            pid = entry.th32ProcessID
            if entry.szExeFile.lower() == "aruser.exe" and session_id(pid) == caller["session_id"]:
                process = api.OpenProcess(0x1000, False, pid)  # QUERY_LIMITED_INFORMATION only.
                if not process:
                    raise TerminalError("client_ownership_unverified")
                try:
                    owner = token_metadata(process)
                    if owner != caller:
                        raise TerminalError("client_ownership_unverified")
                    buffer = ctypes.create_unicode_buffer(32768)
                    size = w.DWORD(len(buffer))
                    if not api.QueryFullProcessImageNameW(process, 0, buffer, ctypes.byref(size)):
                        raise TerminalError("client_ownership_unverified")
                    clients.append({**owner, "pid": pid, "executable": buffer.value,
                                    "visible_gui": pid in visible})
                finally:
                    api.CloseHandle(process)
            found = api.Process32NextW(handle, ctypes.byref(entry))
        if ctypes.get_last_error() != 18:  # ERROR_NO_MORE_FILES; failures are not an empty list.
            raise TerminalError("client_ownership_unverified")
    finally:
        api.CloseHandle(handle)
    return {**caller, "host": win32api.GetComputerName(), "user": win32api.GetUserNameEx(2),
            "clients": clients}


def _attach_existing(policy):
    import os
    import sys
    if any(key in os.environ for key in ("SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY")):
        raise TerminalError("interactive_session_required")
    if sys.platform != "win32":
        raise TerminalError("windows_backend_unavailable")
    try:
        context = _inspect_windows()
        _verify_context(policy, context)
        import pythoncom
        import win32com.client
        active = pythoncom.GetActiveObject(policy["typelib_guid"])
        dispatch = active.QueryInterface(pythoncom.IID_IDispatch)
        return win32com.client.Dispatch(dispatch)
    except TerminalError:
        raise
    except Exception:
        raise TerminalError("client_ownership_unverified") from None


def read_incident(incident_id, config_path, *, factory=None):
    if not config_path:
        raise TerminalError("configuration_required")
    policy = _load_policy(config_path)
    if not _numeric_id(incident_id) or len(incident_id) > policy["incident_field"]["digits"]:
        raise TerminalError("invalid_incident_id")
    if incident_id not in policy["approved_incident_ids"]:
        raise TerminalError("incident_not_approved")
    canonical = policy["incident_field"]["prefix"] + incident_id.zfill(policy["incident_field"]["digits"])
    owned = []
    error = None
    try:
        app = (factory if factory is not None else _attach_existing)(policy)
        default = app.HasDefaultSession()
        if not _integer(default):
            raise TerminalError("session_unavailable")
        session = app.Login2(1)
        if not _integer(session):
            raise TerminalError("session_unavailable")
        if app.GetUser(session) != (None, policy["expected_auth_user"]):
            raise TerminalError("auth_user_mismatch")
        search = app.OpenForm(session, policy["server"], policy["form"], 2, 0)
        owned.append(search)
        entries = search.Query(f"'{policy['incident_field']['id']}' = \"{canonical}\"")
        count = entries.Count
        if type(count) is not int or count != 1:
            raise TerminalError("incident_not_unique")
        entry_id = entries.Item(1).entryId
        if entry_id != canonical:
            raise TerminalError("incident_mismatch")
        display = app.LoadForm(session, policy["server"], policy["form"], entry_id, 3, 0)
        owned.append(display)
        identity = display.GetFieldById(policy["incident_field"]["id"])
        if identity.GetFieldLabel() != policy["incident_field"]["label"] or identity.Value != canonical:
            raise TerminalError("incident_mismatch")
        values = {}
        for spec in policy["fields"]:
            field = display.GetFieldById(spec["id"])
            if field.GetFieldLabel() != spec["label"]:
                raise TerminalError("field_contract_mismatch")
            value = field.Value
            if value is not None and type(value) not in (str, int, float, bool):
                raise TerminalError("field_value_unsupported")
            values[spec["label"]] = value
        result = {"requested_incident_id": incident_id, "canonical_id": canonical,
                  "mode": "live-com-readonly", "source": "live", "values": values,
                  "writes_enabled": False}
        json.dumps(result, allow_nan=False)
    except TerminalError as exc:
        allowed = {"windows_backend_unavailable", "interactive_session_required", "client_ownership_unverified",
                   "session_unavailable", "auth_user_mismatch", "incident_not_unique", "incident_mismatch",
                   "field_contract_mismatch", "field_value_unsupported"}
        error = exc.code if exc.code in allowed else "com_read_failed"
    except Exception:
        error = "com_read_failed"
    finally:
        for form in reversed(owned):
            try:
                form.Close()
            except Exception:
                if error is None:
                    error = "cleanup_failed"
    if error is not None:
        raise TerminalError(error) from None
    return result
