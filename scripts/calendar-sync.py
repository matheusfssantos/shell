#!/usr/bin/env python3
"""Small Google Calendar/Microsoft Graph bridge for the Caelestia shell.

Account metadata is stored below XDG_CONFIG_HOME. OAuth tokens and Google's
desktop client secret are stored in the session Secret Service via secret-tool.
The QML shell only receives normalized calendars and events as JSON.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import http.server
import json
import os
import secrets
import socketserver
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import webbrowser
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any


APP = "caelestia-calendar"
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "caelestia"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "caelestia"
ACCOUNTS_FILE = CONFIG_DIR / "calendar-accounts.json"
CACHE_FILE = STATE_DIR / "calendar-remote-events.json"
GOOGLE_AUTH = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN = "https://oauth2.googleapis.com/token"
GOOGLE_API = "https://www.googleapis.com/calendar/v3"
MICROSOFT_LOGIN = "https://login.microsoftonline.com/common/oauth2/v2.0"
GRAPH_API = "https://graph.microsoft.com/v1.0"
GOOGLE_SCOPE = "openid email profile https://www.googleapis.com/auth/calendar"
MICROSOFT_SCOPE = "offline_access openid profile User.Read Calendars.ReadWrite"
PALETTE = ["#43d17c", "#5aa7ff", "#d291ff", "#ff8b73", "#f2c94c", "#5dd9c1", "#ff79b0"]


class CalendarError(RuntimeError):
    pass


def load_json(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default
    except (OSError, json.JSONDecodeError) as error:
        raise CalendarError(f"Unable to read {path}: {error}") from error


def save_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.chmod(0o600)
    temporary.replace(path)


def accounts() -> list[dict[str, Any]]:
    data = load_json(ACCOUNTS_FILE, {"version": 1, "accounts": []})
    return data.get("accounts", [])


def save_accounts(items: list[dict[str, Any]]) -> None:
    save_json(ACCOUNTS_FILE, {"version": 1, "accounts": items})


def secret_lookup(account_id: str) -> dict[str, Any]:
    result = subprocess.run(
        ["secret-tool", "lookup", "application", APP, "account", account_id],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        raise CalendarError(f"No credentials found for account {account_id}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise CalendarError(f"Invalid credentials for account {account_id}") from error


def secret_store(account_id: str, value: dict[str, Any], label: str) -> None:
    result = subprocess.run(
        [
            "secret-tool",
            "store",
            f"--label=Caelestia Calendar — {label}",
            "application",
            APP,
            "account",
            account_id,
        ],
        input=json.dumps(value),
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise CalendarError(result.stderr.strip() or "Unable to store credentials in Secret Service")


def secret_clear(account_id: str) -> None:
    subprocess.run(
        ["secret-tool", "clear", "application", APP, "account", account_id],
        check=False,
        capture_output=True,
        text=True,
    )


def request_json(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    data: dict[str, Any] | None = None,
    form: dict[str, Any] | None = None,
    timeout: int = 30,
) -> dict[str, Any]:
    body = None
    request_headers = dict(headers or {})
    if data is not None:
        body = json.dumps(data).encode()
        request_headers["Content-Type"] = "application/json"
    elif form is not None:
        body = urllib.parse.urlencode(form).encode()
        request_headers["Content-Type"] = "application/x-www-form-urlencoded"
    request = urllib.request.Request(url, data=body, headers=request_headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = response.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as error:
        details = error.read().decode(errors="replace")
        try:
            parsed = json.loads(details)
            details = parsed.get("error_description") or parsed.get("error", {}).get("message") or details
        except (json.JSONDecodeError, AttributeError):
            pass
        raise CalendarError(f"HTTP {error.code}: {details}") from error
    except urllib.error.URLError as error:
        raise CalendarError(f"Network error: {error.reason}") from error


def bearer(token: str, extra: dict[str, str] | None = None) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}", **(extra or {})}


def account_by_id(account_id: str) -> dict[str, Any]:
    try:
        return next(item for item in accounts() if item["id"] == account_id)
    except StopIteration as error:
        raise CalendarError(f"Unknown account {account_id}") from error


def refresh_google(account: dict[str, Any], credentials: dict[str, Any]) -> dict[str, Any]:
    if credentials.get("expires_at", 0) > time.time() + 90:
        return credentials
    response = request_json(
        GOOGLE_TOKEN,
        method="POST",
        form={
            "client_id": account["client_id"],
            "client_secret": credentials.get("client_secret", ""),
            "refresh_token": credentials["refresh_token"],
            "grant_type": "refresh_token",
        },
    )
    credentials.update(response)
    credentials["expires_at"] = time.time() + int(response.get("expires_in", 3600))
    secret_store(account["id"], credentials, account["label"])
    return credentials


def refresh_microsoft(account: dict[str, Any], credentials: dict[str, Any]) -> dict[str, Any]:
    if credentials.get("expires_at", 0) > time.time() + 90:
        return credentials
    response = request_json(
        f"{MICROSOFT_LOGIN}/token",
        method="POST",
        form={
            "client_id": account["client_id"],
            "refresh_token": credentials["refresh_token"],
            "grant_type": "refresh_token",
            "scope": MICROSOFT_SCOPE,
        },
    )
    if "refresh_token" not in response:
        response["refresh_token"] = credentials["refresh_token"]
    response["expires_at"] = time.time() + int(response.get("expires_in", 3600))
    secret_store(account["id"], response, account["label"])
    return response


def access_token(account: dict[str, Any]) -> str:
    credentials = secret_lookup(account["id"])
    if account["provider"] == "google":
        credentials = refresh_google(account, credentials)
    elif account["provider"] == "microsoft":
        credentials = refresh_microsoft(account, credentials)
    else:
        raise CalendarError(f"Unsupported provider {account['provider']}")
    return credentials["access_token"]


class OAuthHandler(http.server.BaseHTTPRequestHandler):
    response: dict[str, str] = {}

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        OAuthHandler.response = dict(urllib.parse.parse_qsl(urllib.parse.urlparse(self.path).query))
        ok = "code" in OAuthHandler.response
        message = "Conta conectada. Você já pode fechar esta aba." if ok else "Não foi possível conectar a conta."
        page = f"<!doctype html><meta charset=utf-8><title>Caelestia Calendar</title><style>body{{font:18px sans-serif;background:#18191f;color:#eee;padding:4rem}}</style><h1>{message}</h1>"
        self.send_response(200 if ok else 400)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(page.encode())

    def log_message(self, _format: str, *_args: Any) -> None:
        return


def add_account(provider: str, client_id: str, label: str, identity: str, credentials: dict[str, Any]) -> dict[str, Any]:
    items = accounts()
    existing = next((item for item in items if item["provider"] == provider and item.get("identity") == identity), None)
    account_id = existing["id"] if existing else f"{provider}-{uuid.uuid4().hex[:12]}"
    item = {
        "id": account_id,
        "provider": provider,
        "client_id": client_id,
        "label": label or identity,
        "identity": identity,
        "enabled": True,
    }
    items = [current for current in items if current["id"] != account_id]
    items.append(item)
    secret_store(account_id, credentials, item["label"])
    save_accounts(items)
    return item


def connect_google(credentials_path: str, label: str) -> dict[str, Any]:
    raw = load_json(Path(credentials_path).expanduser(), {})
    client = raw.get("installed") or raw.get("web") or raw
    client_id = client.get("client_id")
    client_secret = client.get("client_secret", "")
    if not client_id:
        raise CalendarError("The Google credentials file does not contain a client_id")

    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(24)
    OAuthHandler.response = {}
    with socketserver.TCPServer(("127.0.0.1", 0), OAuthHandler) as server:
        server.timeout = 300
        redirect_uri = f"http://127.0.0.1:{server.server_address[1]}/"
        query = urllib.parse.urlencode(
            {
                "client_id": client_id,
                "redirect_uri": redirect_uri,
                "response_type": "code",
                "scope": GOOGLE_SCOPE,
                "access_type": "offline",
                "prompt": "consent",
                "include_granted_scopes": "true",
                "state": state,
                "code_challenge": challenge,
                "code_challenge_method": "S256",
            }
        )
        webbrowser.open(f"{GOOGLE_AUTH}?{query}")
        print("Aguardando autorização do Google no navegador…", file=sys.stderr, flush=True)
        server.handle_request()
    response = OAuthHandler.response
    if response.get("state") != state or not response.get("code"):
        raise CalendarError(response.get("error_description") or response.get("error") or "Google authorization timed out")
    token = request_json(
        GOOGLE_TOKEN,
        method="POST",
        form={
            "client_id": client_id,
            "client_secret": client_secret,
            "code": response["code"],
            "code_verifier": verifier,
            "redirect_uri": redirect_uri,
            "grant_type": "authorization_code",
        },
    )
    token["expires_at"] = time.time() + int(token.get("expires_in", 3600))
    token["client_secret"] = client_secret
    profile = request_json("https://openidconnect.googleapis.com/v1/userinfo", headers=bearer(token["access_token"]))
    identity = profile.get("email") or profile.get("sub") or "Google"
    return add_account("google", client_id, label, identity, token)


def connect_microsoft(client_id: str, label: str) -> dict[str, Any]:
    device = request_json(
        f"{MICROSOFT_LOGIN}/devicecode",
        method="POST",
        form={"client_id": client_id, "scope": MICROSOFT_SCOPE},
    )
    print(device.get("message", "Abra o navegador para autorizar a conta Microsoft."), file=sys.stderr, flush=True)
    verification_url = device.get("verification_uri_complete")
    if not verification_url:
        subprocess.run(["wl-copy"], input=device.get("user_code", ""), check=False, text=True)
        verification_url = device["verification_uri"]
    webbrowser.open(verification_url)
    deadline = time.time() + int(device.get("expires_in", 900))
    interval = int(device.get("interval", 5))
    token: dict[str, Any] | None = None
    while time.time() < deadline:
        time.sleep(interval)
        try:
            token = request_json(
                f"{MICROSOFT_LOGIN}/token",
                method="POST",
                form={
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                    "client_id": client_id,
                    "device_code": device["device_code"],
                },
            )
            break
        except CalendarError as error:
            message = str(error)
            if "authorization_pending" in message:
                continue
            if "slow_down" in message:
                interval += 5
                continue
            raise
    if not token:
        raise CalendarError("Microsoft authorization timed out")
    token["expires_at"] = time.time() + int(token.get("expires_in", 3600))
    profile = request_json(f"{GRAPH_API}/me?$select=displayName,mail,userPrincipalName", headers=bearer(token["access_token"]))
    identity = profile.get("mail") or profile.get("userPrincipalName") or profile.get("id") or "Microsoft"
    return add_account("microsoft", client_id, label or profile.get("displayName", ""), identity, token)


def parse_datetime(value: str) -> int:
    normalized = value.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return int(parsed.timestamp() * 1000)


def google_event(account: dict[str, Any], calendar: dict[str, Any], event: dict[str, Any]) -> dict[str, Any]:
    all_day = "date" in event.get("start", {})
    if all_day:
        start_ms = int(datetime.combine(date.fromisoformat(event["start"]["date"]), datetime.min.time()).astimezone().timestamp() * 1000)
        end_ms = int(datetime.combine(date.fromisoformat(event["end"]["date"]), datetime.min.time()).astimezone().timestamp() * 1000)
    else:
        start_ms = parse_datetime(event["start"]["dateTime"])
        end_ms = parse_datetime(event["end"]["dateTime"])
    return {
        "id": f"google:{account['id']}:{calendar['providerCalendarId']}:{event['id']}",
        "providerEventId": event["id"],
        "calendarId": calendar["id"],
        "providerCalendarId": calendar["providerCalendarId"],
        "accountId": account["id"],
        "provider": "google",
        "colour": calendar["colour"],
        "title": event.get("summary") or "(Sem título)",
        "location": event.get("location", ""),
        "notes": event.get("description", ""),
        "allDay": all_day,
        "startMs": start_ms,
        "endMs": end_ms,
        "writable": calendar["writable"],
        "htmlLink": event.get("htmlLink", ""),
        "syncState": "synced",
    }


def sync_google(account: dict[str, Any], start: datetime, end: datetime) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    token = access_token(account)
    calendar_data = request_json(f"{GOOGLE_API}/users/me/calendarList?maxResults=250", headers=bearer(token))
    calendars: list[dict[str, Any]] = []
    events: list[dict[str, Any]] = []
    for index, source in enumerate(calendar_data.get("items", [])):
        calendar = {
            "id": f"google:{account['id']}:{source['id']}",
            "providerCalendarId": source["id"],
            "accountId": account["id"],
            "provider": "google",
            "name": source.get("summaryOverride") or source.get("summary") or account["label"],
            "colour": source.get("backgroundColor") or PALETTE[index % len(PALETTE)],
            "writable": source.get("accessRole") in ("owner", "writer"),
            "primary": bool(source.get("primary")),
        }
        calendars.append(calendar)
        params = urllib.parse.urlencode(
            {
                "singleEvents": "true",
                "showDeleted": "false",
                "orderBy": "startTime",
                "maxResults": 2500,
                "timeMin": start.isoformat().replace("+00:00", "Z"),
                "timeMax": end.isoformat().replace("+00:00", "Z"),
            }
        )
        url = f"{GOOGLE_API}/calendars/{urllib.parse.quote(source['id'], safe='')}/events?{params}"
        while url:
            page = request_json(url, headers=bearer(token))
            events.extend(google_event(account, calendar, item) for item in page.get("items", []) if item.get("status") != "cancelled" and item.get("start") and item.get("end"))
            page_token = page.get("nextPageToken")
            url = f"{GOOGLE_API}/calendars/{urllib.parse.quote(source['id'], safe='')}/events?{params}&pageToken={urllib.parse.quote(page_token)}" if page_token else ""
    return calendars, events


def microsoft_event(account: dict[str, Any], calendar: dict[str, Any], event: dict[str, Any]) -> dict[str, Any]:
    start_value = event.get("start", {}).get("dateTime", "")
    end_value = event.get("end", {}).get("dateTime", "")
    return {
        "id": f"microsoft:{account['id']}:{calendar['providerCalendarId']}:{event['id']}",
        "providerEventId": event["id"],
        "calendarId": calendar["id"],
        "providerCalendarId": calendar["providerCalendarId"],
        "accountId": account["id"],
        "provider": "microsoft",
        "colour": calendar["colour"],
        "title": event.get("subject") or "(Sem título)",
        "location": event.get("location", {}).get("displayName", ""),
        "notes": event.get("bodyPreview", ""),
        "allDay": bool(event.get("isAllDay")),
        "startMs": parse_datetime(start_value),
        "endMs": parse_datetime(end_value),
        "writable": calendar["writable"],
        "htmlLink": event.get("webLink", ""),
        "syncState": "synced",
    }


def graph_pages(url: str, token: str, extra_headers: dict[str, str] | None = None) -> list[dict[str, Any]]:
    values: list[dict[str, Any]] = []
    while url:
        page = request_json(url, headers=bearer(token, extra_headers))
        values.extend(page.get("value", []))
        url = page.get("@odata.nextLink", "")
    return values


def sync_microsoft(account: dict[str, Any], start: datetime, end: datetime) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    token = access_token(account)
    sources = graph_pages(f"{GRAPH_API}/me/calendars?$top=100", token)
    calendars: list[dict[str, Any]] = []
    events: list[dict[str, Any]] = []
    for index, source in enumerate(sources):
        calendar = {
            "id": f"microsoft:{account['id']}:{source['id']}",
            "providerCalendarId": source["id"],
            "accountId": account["id"],
            "provider": "microsoft",
            "name": source.get("name") or account["label"],
            "colour": source.get("hexColor") or PALETTE[(index + 1) % len(PALETTE)],
            "writable": bool(source.get("canEdit", True)),
            "primary": bool(source.get("isDefaultCalendar")),
        }
        calendars.append(calendar)
        calendar_id = urllib.parse.quote(source["id"], safe="")
        params = urllib.parse.urlencode(
            {
                "startDateTime": start.isoformat().replace("+00:00", "Z"),
                "endDateTime": end.isoformat().replace("+00:00", "Z"),
                "$top": 1000,
                "$select": "id,subject,start,end,isAllDay,location,bodyPreview,webLink,isCancelled",
            }
        )
        url = f"{GRAPH_API}/me/calendars/{calendar_id}/calendarView?{params}"
        source_events = graph_pages(url, token, {"Prefer": 'outlook.timezone="UTC"'})
        events.extend(microsoft_event(account, calendar, item) for item in source_events if not item.get("isCancelled") and item.get("start") and item.get("end"))
    return calendars, events


def sync_all() -> dict[str, Any]:
    now = datetime.now(UTC)
    start = now - timedelta(days=62)
    end = now + timedelta(days=370)
    all_calendars: list[dict[str, Any]] = []
    all_events: list[dict[str, Any]] = []
    statuses: list[dict[str, Any]] = []
    for account in accounts():
        if not account.get("enabled", True):
            continue
        try:
            if account["provider"] == "google":
                calendars, events = sync_google(account, start, end)
            elif account["provider"] == "microsoft":
                calendars, events = sync_microsoft(account, start, end)
            else:
                raise CalendarError(f"Unsupported provider {account['provider']}")
            all_calendars.extend(calendars)
            all_events.extend(events)
            statuses.append({"accountId": account["id"], "ok": True})
        except CalendarError as error:
            statuses.append({"accountId": account["id"], "ok": False, "error": str(error)})
    result = {
        "version": 1,
        "syncedAt": int(time.time() * 1000),
        "accounts": accounts(),
        "calendars": all_calendars,
        "events": all_events,
        "statuses": statuses,
    }
    save_json(CACHE_FILE, result)
    return result


def decode_payload(encoded: str) -> dict[str, Any]:
    try:
        if encoded.lstrip().startswith("{"):
            return json.loads(encoded)
        return json.loads(base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4)))
    except (ValueError, json.JSONDecodeError) as error:
        raise CalendarError("Invalid event payload") from error


def iso_utc(milliseconds: int) -> str:
    return datetime.fromtimestamp(milliseconds / 1000, UTC).isoformat().replace("+00:00", "Z")


def google_payload(payload: dict[str, Any]) -> dict[str, Any]:
    if payload.get("allDay"):
        start = datetime.fromtimestamp(payload["startMs"] / 1000).astimezone().date()
        end = datetime.fromtimestamp(payload["endMs"] / 1000).astimezone().date()
        start_data, end_data = {"date": start.isoformat()}, {"date": end.isoformat()}
    else:
        start_data, end_data = {"dateTime": iso_utc(payload["startMs"])}, {"dateTime": iso_utc(payload["endMs"])}
    return {
        "summary": payload.get("title", ""),
        "description": payload.get("notes", ""),
        "location": payload.get("location", ""),
        "start": start_data,
        "end": end_data,
    }


def microsoft_payload(payload: dict[str, Any]) -> dict[str, Any]:
    if payload.get("allDay"):
        start_date = datetime.fromtimestamp(payload["startMs"] / 1000).astimezone().date().isoformat()
        end_date = datetime.fromtimestamp(payload["endMs"] / 1000).astimezone().date().isoformat()
        start_value = f"{start_date}T00:00:00"
        end_value = f"{end_date}T00:00:00"
    else:
        start_value = iso_utc(payload["startMs"]).removesuffix("Z")
        end_value = iso_utc(payload["endMs"]).removesuffix("Z")
    return {
        "subject": payload.get("title", ""),
        "body": {"contentType": "text", "content": payload.get("notes", "")},
        "location": {"displayName": payload.get("location", "")},
        "isAllDay": bool(payload.get("allDay")),
        "start": {"dateTime": start_value, "timeZone": "UTC"},
        "end": {"dateTime": end_value, "timeZone": "UTC"},
    }


def mutate_event(action: str, payload: dict[str, Any]) -> dict[str, Any]:
    calendar_id = payload.get("calendarId")
    cached = load_json(CACHE_FILE, {"calendars": []})
    calendar = next((item for item in cached.get("calendars", []) if item["id"] == calendar_id), None)
    if not calendar:
        raise CalendarError(f"Unknown calendar {calendar_id}")
    account = account_by_id(calendar["accountId"])
    token = access_token(account)
    provider_calendar_id = urllib.parse.quote(calendar["providerCalendarId"], safe="")
    provider_event_id = urllib.parse.quote(payload.get("providerEventId", ""), safe="")
    if account["provider"] == "google":
        base = f"{GOOGLE_API}/calendars/{provider_calendar_id}/events"
        if action == "create":
            return request_json(base, method="POST", headers=bearer(token), data=google_payload(payload))
        if action == "update":
            return request_json(f"{base}/{provider_event_id}", method="PATCH", headers=bearer(token), data=google_payload(payload))
        request_json(f"{base}/{provider_event_id}", method="DELETE", headers=bearer(token))
        return {}
    if account["provider"] == "microsoft":
        base = f"{GRAPH_API}/me/calendars/{provider_calendar_id}/events"
        if action == "create":
            return request_json(base, method="POST", headers=bearer(token), data=microsoft_payload(payload))
        if action == "update":
            return request_json(f"{base}/{provider_event_id}", method="PATCH", headers=bearer(token), data=microsoft_payload(payload))
        request_json(f"{base}/{provider_event_id}", method="DELETE", headers=bearer(token))
        return {}
    raise CalendarError(f"Unsupported provider {account['provider']}")


def status() -> dict[str, Any]:
    cached = load_json(CACHE_FILE, {"version": 1, "calendars": [], "events": [], "statuses": []})
    cached["accounts"] = accounts()
    return cached


def disconnect(account_id: str) -> dict[str, Any]:
    items = accounts()
    if not any(item["id"] == account_id for item in items):
        raise CalendarError(f"Unknown account {account_id}")
    save_accounts([item for item in items if item["id"] != account_id])
    secret_clear(account_id)
    return {"removed": account_id}


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Caelestia multi-account calendar bridge")
    subparsers = result.add_subparsers(dest="command", required=True)
    subparsers.add_parser("status")
    subparsers.add_parser("sync")
    google = subparsers.add_parser("connect-google")
    google.add_argument("--credentials", required=True, help="Google OAuth desktop credentials JSON")
    google.add_argument("--label", default="")
    microsoft = subparsers.add_parser("connect-microsoft")
    microsoft.add_argument("--client-id", required=True, help="Microsoft public client application ID")
    microsoft.add_argument("--label", default="")
    remove = subparsers.add_parser("disconnect")
    remove.add_argument("account_id")
    for name in ("create", "update", "delete"):
        mutation = subparsers.add_parser(name)
        mutation.add_argument("payload", help="JSON or URL-safe base64 encoded JSON")
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        if args.command == "status":
            result = status()
        elif args.command == "sync":
            result = sync_all()
        elif args.command == "connect-google":
            result = connect_google(args.credentials, args.label)
        elif args.command == "connect-microsoft":
            result = connect_microsoft(args.client_id, args.label)
        elif args.command == "disconnect":
            result = disconnect(args.account_id)
        else:
            result = mutate_event(args.command, decode_payload(args.payload))
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (CalendarError, KeyError, ValueError) as error:
        print(json.dumps({"error": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
