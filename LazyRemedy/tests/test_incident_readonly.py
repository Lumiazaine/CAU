"""All identifiers, fields, hosts and users below are synthetic."""
import json
import pytest
from lazyremedy.terminal import cli
from lazyremedy.terminal.domain import TerminalError


def config():
    return {
        "enabled": True, "read_only": True,
        "expected_host": "SYN-HOST", "expected_user": "SYN\\tester",
        "expected_session_id": 7, "client_executable": r"C:\Synthetic\aruser.exe",
        "typelib_guid": "{12345678-1234-1234-1234-123456789ABC}",
        "server": "SYN-SERVER", "form": "SYN:Incident",
        "expected_auth_user": "synthetic.tester",
        "incident_field": {"id": 900001, "label": "Synthetic incident", "prefix": "SYN", "digits": 10},
        "approved_incident_ids": ["7654321"],
        "fields": [{"id": 900002, "label": "Synthetic summary"}],
    }


class Field:
    def __init__(self, label, value: object):
        self.label = label
        self.Value = value  # Formal COM property getter returns the scalar directly.

    def GetFieldLabel(self):
        return self.label


class Entries:
    Count = 1

    def Item(self, index):
        assert index == 1
        return type("Entry", (), {"entryId": "SYN0007654321"})()


class Form:
    def __init__(self, log, display=False):
        self.log = log
        self.display = display
        self.closed = False
        self.entries = Entries()
        self.fields = {900001: Field("Synthetic incident", "SYN0007654321"),
                       900002: Field("Synthetic summary", "Synthetic result")}

    def Query(self, qualifier):
        assert not self.display
        self.log.append(("Query", qualifier))
        return self.entries

    def GetFieldById(self, field_id):
        assert self.display
        self.log.append(("GetFieldById", field_id))
        return self.fields[field_id]

    def Close(self):
        self.closed = True
        self.log.append(("Close", self.display))


class App:
    def __init__(self):
        self.log = []
        self.search = Form(self.log)
        self.display = Form(self.log, True)

    def HasDefaultSession(self):
        return 1

    def Login2(self, mode):
        assert mode == 1
        self.log.append(("Login2", mode))
        return 17

    def GetUser(self, session):
        assert session == 17
        return (None, "synthetic.tester")

    def OpenForm(self, *args):
        assert args == (17, "SYN-SERVER", "SYN:Incident", 2, 0)
        self.log.append(("OpenForm",))
        return self.search

    def LoadForm(self, *args):
        assert args == (17, "SYN-SERVER", "SYN:Incident", "SYN0007654321", 3, 0)
        self.log.append(("LoadForm",))
        return self.display


def saved(tmp_path, data=None):
    path = tmp_path / "synthetic.json"
    path.write_text(json.dumps(config() if data is None else data), encoding="utf-8")
    return path


def test_approved_incident_reads_exact_contract_and_closes_only_owned_forms(tmp_path):
    from lazyremedy.terminal.windows_readonly import read_incident
    app = App()
    result = read_incident("7654321", saved(tmp_path), factory=lambda policy: app)
    assert result == {"requested_incident_id": "7654321", "canonical_id": "SYN0007654321",
                      "mode": "live-com-readonly", "source": "live",
                      "values": {"Synthetic summary": "Synthetic result"}, "writes_enabled": False}
    assert ("Query", "'900001' = \"SYN0007654321\"") in app.log
    assert app.search.closed and app.display.closed
    assert app.log[-2:] == [("Close", True), ("Close", False)]


@pytest.mark.parametrize("update", [
    {"enabled": False}, {"enabled": 1}, {"read_only": False}, {"read_only": "true"},
    {"write_enabled": True}, {"password": "not-a-secret"},
    {"expected_host": ""}, {"expected_user": " SYN\\tester"},
    {"expected_session_id": 0}, {"expected_session_id": True},
    {"client_executable": "aruser.exe"}, {"client_executable": r"C:\Synthetic\other.exe"},
    {"typelib_guid": "invalid"}, {"server": "SYN\nSERVER"}, {"form": ""},
    {"expected_auth_user": ""}, {"approved_incident_ids": []},
    {"approved_incident_ids": [7654321]}, {"approved_incident_ids": ["07654321"]},
    {"approved_incident_ids": ["7654321", "7654321"]},
    {"fields": []}, {"fields": [{"id": "900002", "label": "Synthetic summary"}]},
    {"fields": [{"id": True, "label": "Synthetic summary"}]},
    {"fields": [{"id": 900002, "label": "password"}]},
    {"fields": [{"id": 900002, "label": "Contraseña"}]},
    {"fields": [{"id": 900002, "label": "token"}]},
    {"fields": [{"id": 900002, "label": "summary", "extra": True}]},
    {"fields": [{"id": 900002, "label": "summary"}, {"id": 900002, "label": "status"}]},
    {"fields": [{"id": 900002, "label": "summary"}, {"id": 900003, "label": "summary"}]},
    {"incident_field": {"id": 900001, "label": "Incident", "prefix": 'SYN\" OR ', "digits": 10}},
    {"incident_field": {"id": 900001, "label": "Incident", "prefix": "SYN", "digits": True}},
    {"incident_field": {"id": 900001, "label": "Incident", "prefix": "SYN", "digits": 3}},
    {"incident_field": {"id": 0, "label": "Incident", "prefix": "SYN", "digits": 10}},
    {"incident_field": {"id": 900001, "label": "password", "prefix": "SYN", "digits": 10}},
])
def test_invalid_configuration_never_attaches(tmp_path, update):
    from lazyremedy.terminal.windows_readonly import read_incident
    data = config()
    data.update(update)
    with pytest.raises(TerminalError, match="^configuration_invalid$"):
        read_incident("7654321", saved(tmp_path, data), factory=lambda _: pytest.fail("attached"))


@pytest.mark.parametrize("label", [
    "Credential", "Credentials", "API key", "Private key", "passwd", "pwd", "Clave de acceso",
    "Credencial", "Credenciales", "password", "Contraseña", "secret", "token", "auth",
    "Authentication", "Authorization", "verificationCode", "OTP", "PIN", "Access key",
    "Client secret", "Authorization code", "Crédentiáls", "Credenciáles", "Pásswórd",
    "Cláve de accéso", "Código de verificación", "Contrasen\u0303a", "Sécret",
    "API_key", "API-key", "A.P.I. key", "Private-Key", "p.a.s.s.w.d", "p_w_d",
    "Verifi cation-Code", "O.T.P.", "A\u200bP\u200bI key", "creden\u200dtials",
    "Ｃｒｅｄｅｎｔｉａｌｓ", "ＡＰＩ　ＫＥＹ", "pRiVaTeKeY", "apikey", "privatekey",
    "clavedeacceso", "accesskey", "authCode", "SYN Credential", "Synthetic API-key",
    "One-time password", "Authentication code", "Autenticación", "Autorización",
])
@pytest.mark.parametrize("target", ["incident_field", "fields"])
def test_secret_labels_rejected_before_attach_even_when_approved(tmp_path, label, target):
    from lazyremedy.terminal.windows_readonly import read_incident
    data = config()
    spec = data["incident_field"] if target == "incident_field" else data["fields"][0]
    spec["label"] = label
    app = App()
    app.display.fields[spec["id"]].label = label
    attached = []

    def factory(policy):
        attached.append(policy)
        return app

    with pytest.raises(TerminalError, match="^configuration_invalid$"):
        read_incident("7654321", saved(tmp_path, data), factory=factory)
    assert attached == []
    assert app.log == []


@pytest.mark.parametrize("label", [
    "Description", "Title", "Fecha", "Lugar", "Descripción", "Fecha de cierre",
    "Key location", "Author", "Ｔｉｔｌｅ", "Descripcio\u0301n",
])
@pytest.mark.parametrize("target", ["incident_field", "fields"])
def test_ordinary_labels_remain_exact_and_values_are_not_secret_scanned(tmp_path, label, target):
    from lazyremedy.terminal.windows_readonly import read_incident
    data = config()
    spec = data["incident_field"] if target == "incident_field" else data["fields"][0]
    spec["label"] = label
    app = App()
    app.display.fields[spec["id"]].label = label
    value = "Synthetic description mentioning password, credentials, API key and OTP"
    app.display.fields[900002].Value = value
    result = read_incident("7654321", saved(tmp_path, data), factory=lambda _: app)
    assert result["values"] == {data["fields"][0]["label"]: value}
    assert result["requested_incident_id"] == "7654321"
    assert result["canonical_id"] == "SYN0007654321"
    assert app.search.closed and app.display.closed


@pytest.mark.parametrize("incident_id", [7654321, "", "7654321 ", " 7654321", "07654321",
                                       "７６５４３２１", "7654321\\n", '7654321\" OR 1=1',
                                       "SYN0007654321", "1234567"])
def test_input_exact_ascii_approved_no_repair_no_query(tmp_path, incident_id):
    from lazyremedy.terminal.windows_readonly import read_incident
    with pytest.raises(TerminalError, match="^(invalid_incident_id|incident_not_approved)$"):
        read_incident(incident_id, saved(tmp_path), factory=lambda _: pytest.fail("attached"))


@pytest.mark.parametrize("content", ["{bad", "[]", '{"enabled":true,"enabled":false}', "null"])
def test_bad_json_is_sanitized(tmp_path, content):
    from lazyremedy.terminal.windows_readonly import read_incident
    path = tmp_path / "bad.json"
    path.write_text(content)
    with pytest.raises(TerminalError, match="^configuration_invalid$"):
        read_incident("7654321", path, factory=lambda _: pytest.fail("attached"))


def test_missing_config_file_is_sanitized(tmp_path):
    from lazyremedy.terminal.windows_readonly import read_incident
    with pytest.raises(TerminalError, match="^configuration_invalid$"):
        read_incident("7654321", tmp_path / "missing.json")


@pytest.mark.parametrize("stage", ["attach", "default_session", "login", "auth_user", "open", "query", "load", "identity", "field", "close"])
def test_failures_sanitized_and_all_owned_forms_closed(tmp_path, stage):
    from lazyremedy.terminal.windows_readonly import read_incident
    app = App()
    raw = RuntimeError("ARERR 9999 private server/user/path detail")

    def fail(*_):
        raise raw

    if stage == "attach":
        factory = fail
    else:
        factory = lambda _: app
        if stage in {"default_session", "login", "auth_user", "open", "load"}:
            method = {"default_session": "HasDefaultSession", "login": "Login2",
                      "auth_user": "GetUser", "open": "OpenForm", "load": "LoadForm"}[stage]
            setattr(app, method, fail)
        elif stage == "query":
            app.search.Query = fail
        elif stage == "identity":
            app.display.GetFieldById = fail
        elif stage == "field":
            app.display.fields[900002].GetFieldLabel = fail
        else:
            def failed_close():
                app.display.closed = True
                raise raw
            app.display.Close = failed_close
    with pytest.raises(TerminalError) as exc:
        read_incident("7654321", saved(tmp_path), factory=factory)
    assert exc.value.code in {"com_read_failed", "cleanup_failed"}
    assert "private" not in str(exc.value)
    if stage in {"query", "load", "identity", "field", "close"}:
        assert app.search.closed
    if stage in {"identity", "field", "close"}:
        assert app.display.closed


@pytest.mark.parametrize("count", [0, 2, -1, True, "1"])
def test_count_must_be_typed_exactly_one(tmp_path, count):
    from lazyremedy.terminal.windows_readonly import read_incident
    app = App()
    app.search.entries.Count = count
    with pytest.raises(TerminalError, match="^incident_not_unique$"):
        read_incident("7654321", saved(tmp_path), factory=lambda _: app)
    assert app.search.closed and not app.display.closed
    assert ("LoadForm",) not in app.log


@pytest.mark.parametrize("stage", ["default", "session", "auth", "entry", "readback", "identity_label", "field_label", "secret_label", "object_value"])
def test_contract_mismatch_stops_without_writes(tmp_path, stage):
    from lazyremedy.terminal.windows_readonly import read_incident
    app = App()
    if stage == "default":
        app.HasDefaultSession = lambda: 0
    elif stage == "session":
        app.Login2 = lambda _: 0
    elif stage == "auth":
        app.GetUser = lambda _: (None, "other.synthetic.user")
    elif stage == "entry":
        app.search.entries.Item = lambda _: type("Entry", (), {"entryId": "SYN0001234567"})()
    elif stage == "readback":
        app.display.fields[900001].Value = "SYN0001234567"
    elif stage == "identity_label":
        app.display.fields[900001].label = "Another incident field"
    elif stage == "object_value":
        app.display.fields[900002].Value = object()
    else:
        app.display.fields[900002].label = "password" if stage == "secret_label" else "Unknown"
    with pytest.raises(TerminalError):
        read_incident("7654321", saved(tmp_path), factory=lambda _: app)
    if ("OpenForm",) in app.log:
        assert app.search.closed
    if ("LoadForm",) in app.log:
        assert app.display.closed


def test_cli_incident_explicit_config_bypasses_legacy_bootstrap(tmp_path, monkeypatch, capsys):
    from lazyremedy.terminal import windows_readonly
    monkeypatch.setattr(cli, "build_application", lambda *_: pytest.fail("legacy bootstrap called"))
    monkeypatch.setattr(windows_readonly, "_attach_existing", lambda _: App(), raising=False)
    assert cli.main(["incident", "--id", "7654321", "--com-config", str(saved(tmp_path))]) == 0
    out = capsys.readouterr()
    assert not out.err
    assert json.loads(out.out)["writes_enabled"] is False


def snapshot():
    return {"host": "SYN-HOST", "user": "SYN\\tester", "session_id": 7,
            "sid": "S-1-5-21-SYN", "logon_id": 42,
            "clients": [{"pid": 123, "session_id": 7, "sid": "S-1-5-21-SYN", "logon_id": 42,
                         "executable": r"C:\Synthetic\aruser.exe", "visible_gui": True}]}


@pytest.mark.parametrize("change", ["host", "user", "zero_session", "session", "none", "two",
                                   "foreign_sid", "foreign_session", "foreign_logon", "path", "no_gui"])
def test_windows_ownership_guard_is_fail_closed(change):
    from lazyremedy.terminal import windows_readonly as module
    data = snapshot()
    if change in {"host", "user"}:
        data[change] = "OTHER-SYNTHETIC"
    elif change == "zero_session":
        data["session_id"] = 0
    elif change == "session":
        data["session_id"] = 9
    elif change == "none":
        data["clients"] = []
    elif change == "two":
        data["clients"] *= 2
    elif change in {"foreign_sid", "foreign_session", "foreign_logon"}:
        key = {"foreign_sid": "sid", "foreign_session": "session_id", "foreign_logon": "logon_id"}[change]
        data["clients"][0][key] = "other-synthetic"
    elif change == "path":
        data["clients"][0]["executable"] = r"C:\OtherSynthetic\aruser.exe"
    else:
        data["clients"][0]["visible_gui"] = False
    with pytest.raises(TerminalError):
        module._verify_context(config(), data)


def test_windows_ownership_guard_accepts_single_same_sid_logon_gui():
    from lazyremedy.terminal import windows_readonly as module
    assert module._verify_context(config(), snapshot()) == 123


@pytest.mark.parametrize("key", ["SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY"])
def test_attach_refuses_ssh_before_windows_inspection(monkeypatch, key):
    from lazyremedy.terminal import windows_readonly as module
    monkeypatch.setenv(key, "synthetic")
    monkeypatch.setattr(module, "_inspect_windows", lambda: pytest.fail("inspected"), raising=False)
    with pytest.raises(TerminalError, match="^interactive_session_required$"):
        module._attach_existing(config())


def test_real_backend_is_lazy_unavailable_on_non_windows(monkeypatch):
    import sys
    from lazyremedy.terminal import windows_readonly as module
    monkeypatch.setattr(sys, "platform", "linux")
    for key in ("SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY"):
        monkeypatch.delenv(key, raising=False)
    with pytest.raises(TerminalError, match="^windows_backend_unavailable$"):
        module._attach_existing(config())


def test_attach_uses_only_running_object_idispatch_after_guard(monkeypatch):
    import sys
    import types
    from lazyremedy.terminal import windows_readonly as module
    for key in ("SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY"):
        monkeypatch.delenv(key, raising=False)
    monkeypatch.setattr(sys, "platform", "win32")
    monkeypatch.setattr(module, "_inspect_windows", snapshot, raising=False)
    calls = []
    dispatch = object()
    app = App()
    class Running:
        def QueryInterface(self, iid):
            assert iid == "SYN-IDispatch"
            calls.append("QI")
            return dispatch
    def active(guid):
        assert guid == config()["typelib_guid"]
        calls.append("GetActiveObject")
        return Running()
    def wrapper(value):
        assert value is dispatch  # Never a ProgID string / class factory.
        calls.append("Dispatch-existing")
        return app
    monkeypatch.setitem(sys.modules, "pythoncom", types.SimpleNamespace(
        GetActiveObject=active, IID_IDispatch="SYN-IDispatch"))
    client = types.SimpleNamespace(Dispatch=wrapper)
    monkeypatch.setitem(sys.modules, "win32com", types.SimpleNamespace(client=client))
    monkeypatch.setitem(sys.modules, "win32com.client", client)
    assert module._attach_existing(config()) is app
    assert calls == ["GetActiveObject", "QI", "Dispatch-existing"]


@pytest.mark.parametrize("stage", ["ok", "session_zero", "snapshot_failed", "process_open_failed",
                                   "foreign_owner", "path_failed", "enumeration_failed"])
def test_windows_native_inspection_reads_only_same_session_client_metadata(monkeypatch, stage):
    import ctypes
    import types
    import sys
    from lazyremedy.terminal import windows_readonly as module
    calls = []
    processes = iter([(123, "aruser.exe"), (456, "aruser.exe"), (789, "other.exe")])
    class Function:
        def __init__(self, fn):
            self.fn = fn
        def __call__(self, *args):
            return self.fn(*args)
    def next_process(handle, pointer):
        item = next(processes, None)
        if item is None:
            ctypes.set_last_error(5 if stage == "enumeration_failed" else 18)
            return 0
        pointer._obj.th32ProcessID, pointer._obj.szExeFile = item
        return 1
    def session(pid, pointer):
        pointer._obj.value = 9 if pid == 456 else 7
        return 1
    def image(handle, flags, buffer, length):
        calls.append(("image", handle))
        if stage == "path_failed":
            return 0
        buffer.value = r"C:\Synthetic\aruser.exe"
        return 1
    def open_process(rights, inherit, pid):
        assert rights == 0x1000 and not inherit and pid == 123
        calls.append(("open", pid))
        return None if stage == "process_open_failed" else 123
    api = types.SimpleNamespace(**{name: Function(fn) for name, fn in {
        "CreateToolhelp32Snapshot": lambda flags, pid: ctypes.c_void_p(-1).value if stage == "snapshot_failed" else 1000,
        "Process32FirstW": next_process, "Process32NextW": next_process,
        "GetCurrentProcess": lambda: -1, "GetCurrentProcessId": lambda: 321,
        "ProcessIdToSessionId": session, "OpenProcess": open_process,
        "QueryFullProcessImageNameW": image,
        "CloseHandle": lambda handle: calls.append(("close", handle)) or 1,
    }.items()})
    last_error = [0]
    monkeypatch.setattr(ctypes, "set_last_error", lambda value: last_error.__setitem__(0, value), raising=False)
    monkeypatch.setattr(ctypes, "get_last_error", lambda: last_error[0], raising=False)
    monkeypatch.setattr(ctypes, "WinDLL", lambda *_args, **_kwargs: api, raising=False)
    class Token:
        def __init__(self, handle):
            self.handle = handle
        def Close(self):
            calls.append(("token-close",))
    def info(token, kind):
        if kind == 1:
            return ("S-1-5-21-OTHER-SYN" if stage == "foreign_owner" and token.handle == 123 else "S-1-5-21-SYN", 0)
        return {"AuthenticationId": 42} if kind == 10 else (0 if stage == "session_zero" else 7)
    monkeypatch.setitem(sys.modules, "win32security", types.SimpleNamespace(
        OpenProcessToken=lambda handle, rights: Token(handle), GetTokenInformation=info,
        TokenUser=1, TokenSessionId=12, TokenStatistics=10,
        ConvertSidToStringSid=lambda sid: sid))
    monkeypatch.setitem(sys.modules, "win32api", types.SimpleNamespace(
        GetComputerName=lambda: "SYN-HOST", GetUserNameEx=lambda _: "SYN\\tester"))
    monkeypatch.setitem(sys.modules, "win32gui", types.SimpleNamespace(
        EnumWindows=lambda callback, data: callback(99, data), IsWindowVisible=lambda _: True))
    monkeypatch.setitem(sys.modules, "win32process", types.SimpleNamespace(
        GetWindowThreadProcessId=lambda _: (1, 123)))
    if stage == "ok":
        assert module._inspect_windows() == snapshot()
        assert ("open", 123) in calls and ("close", 123) in calls and ("close", 1000) in calls
        assert calls.count(("token-close",)) == 2
    else:
        with pytest.raises(TerminalError):
            module._inspect_windows()
        if stage not in {"session_zero", "snapshot_failed"}:
            assert ("close", 1000) in calls
        if stage in {"foreign_owner", "path_failed", "enumeration_failed"}:
            assert ("close", 123) in calls
        if stage == "foreign_owner":
            assert ("image", 123) not in calls


def test_dependency_terminalerror_code_cannot_leak_private_detail(tmp_path):
    from lazyremedy.terminal.windows_readonly import read_incident
    def fail(_):
        raise TerminalError("private synthetic server/user/path")
    with pytest.raises(TerminalError, match="^com_read_failed$"):
        read_incident("7654321", saved(tmp_path), factory=fail)


def test_invalid_ownership_prevents_rot_lookup(monkeypatch):
    import sys
    import types
    from lazyremedy.terminal import windows_readonly as module
    monkeypatch.setattr(sys, "platform", "win32")
    for key in ("SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY"):
        monkeypatch.delenv(key, raising=False)
    context = snapshot()
    context["clients"][0]["sid"] = "S-1-5-21-OTHER-SYN"
    monkeypatch.setattr(module, "_inspect_windows", lambda: context)
    monkeypatch.setitem(sys.modules, "pythoncom", types.SimpleNamespace(
        GetActiveObject=lambda *_: pytest.fail("ROT lookup before ownership")))
    with pytest.raises(TerminalError, match="^client_ownership_unverified$"):
        module._attach_existing(config())


def test_injected_backend_never_imports_windows_dependencies(tmp_path, monkeypatch):
    import builtins
    from lazyremedy.terminal.windows_readonly import read_incident
    original = builtins.__import__
    def checked(name, *args, **kwargs):
        if name.startswith(("win32", "pythoncom")):
            pytest.fail("eager Windows import")
        return original(name, *args, **kwargs)
    monkeypatch.setattr(builtins, "__import__", checked)
    assert read_incident("7654321", saved(tmp_path), factory=lambda _: App())["source"] == "live"


def test_no_mutator_or_active_user_form_dependency_in_adapter():
    import ast
    from pathlib import Path
    from lazyremedy.terminal import windows_readonly as module
    source = ast.parse(Path(module.__file__).read_text())
    forbidden = {"CoCreateInstance", "CreateProcess", "Popen", "RunMacro", "Submit", "Modify", "Logout", "GetActiveForm"}
    assert not any(isinstance(node, ast.Attribute) and node.attr in forbidden for node in ast.walk(source))
    assert not any(isinstance(node, (ast.Assign, ast.AugAssign, ast.AnnAssign)) and
                   any(isinstance(target, ast.Attribute) and target.attr in {"Value", "get"}
                       for target in (node.targets if isinstance(node, ast.Assign) else [node.target]))
                   for node in ast.walk(source))


def test_cli_incident_without_config_fails_before_bootstrap(monkeypatch, capsys):
    monkeypatch.setattr(cli, "build_application", lambda *_: pytest.fail("legacy bootstrap called"))
    try:
        code = cli.main(["incident", "--id", "7654321"])
    except SystemExit as exc:
        pytest.fail(f"incident branch absent: {exc.code}")
    assert code == 2
    out = capsys.readouterr()
    assert not out.out
    assert json.loads(out.err) == {"error": "configuration_required"}


@pytest.mark.parametrize("target", ["fields", "incident_field"])
@pytest.mark.parametrize("base", ["password", "contraseña", "secret", "token", "cookie", "authorization"])
@pytest.mark.parametrize("variant", ["fullwidth", "separated", "accented", "invisible"])
def test_normalized_labels_preserve_every_existing_secret_denial(tmp_path, target, base, variant):
    from lazyremedy.terminal.windows_readonly import read_incident
    if variant == "fullwidth":
        label = "".join(chr(ord(c) + 0xFEE0) if 0x21 <= ord(c) <= 0x7E else c for c in base)
    elif variant == "separated":
        label = ".".join(base)
    elif variant == "accented":
        label = base[:1] + "\u0301" + base[1:]
    else:
        label = "\u200b".join(base)
    policy = config()
    if target == "fields":
        policy["fields"][0]["label"] = label
    else:
        policy["incident_field"]["label"] = label
    def forbidden_attach(_):
        pytest.fail("known secret label reached COM attach")
    with pytest.raises(TerminalError, match="^configuration_invalid$"):
        read_incident("7654321", saved(tmp_path, policy), factory=forbidden_attach)
