"""Minimal App Store Connect API client (ES256 JWT via openssl, no third-party packages).

The private key never leaves ~/.appstoreconnect/private_keys; only the key id and
issuer id live here. Override with ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH.
"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

KEY_ID = os.environ.get("ASC_KEY_ID", "AN4XF9Y8MM")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "8131d42a-11cd-481c-aba6-8a9ca9b4b906")
KEY_PATH = os.path.expanduser(
    os.environ.get("ASC_KEY_PATH", f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
)
BASE_URL = "https://api.appstoreconnect.apple.com"


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _der_to_raw(der: bytes) -> bytes:
    """DER SEQUENCE{INTEGER r, INTEGER s} -> fixed 64-byte r||s as JWT expects."""
    assert der[0] == 0x30
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    assert der[i] == 0x02
    length = der[i + 1]
    r = der[i + 2 : i + 2 + length]
    i += 2 + length
    assert der[i] == 0x02
    length = der[i + 1]
    s = der[i + 2 : i + 2 + length]
    return r[-32:].rjust(32, b"\0") + s[-32:].rjust(32, b"\0")


_token_cache = {"value": None, "expires": 0}


def token() -> str:
    now = int(time.time())
    if _token_cache["value"] and now < _token_cache["expires"] - 60:
        return _token_cache["value"]
    header = _b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    payload = _b64url(
        json.dumps({"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}).encode()
    )
    signing_input = f"{header}.{payload}".encode()
    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(signing_input)
        path = f.name
    try:
        der = subprocess.check_output(["openssl", "dgst", "-sha256", "-sign", KEY_PATH, path])
    finally:
        os.unlink(path)
    _token_cache["value"] = f"{header}.{payload}.{_b64url(_der_to_raw(der))}"
    _token_cache["expires"] = now + 1200
    return _token_cache["value"]


def request(method: str, path: str, body=None, params=None, headers=None, raw=False):
    url = path if path.startswith("http") else BASE_URL + path
    if params:
        query = "&".join(f"{k}={v}" for k, v in params.items())
        url += ("&" if "?" in url else "?") + query
    data = None
    hdrs = {"Authorization": f"Bearer {token()}"}
    if body is not None:
        if raw:
            data = body
        else:
            data = json.dumps(body).encode()
            hdrs["Content-Type"] = "application/json"
    if headers:
        hdrs.update(headers)
    req = urllib.request.Request(url, data=data, method=method, headers=hdrs)
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read()
            return json.loads(content) if content and not raw else None
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        print(f"HTTP {e.code} {method} {url}\n{detail[:1500]}", file=sys.stderr)
        raise


def get(path, params=None):
    return request("GET", path, params=params)


def post(path, body):
    return request("POST", path, body=body)


def patch(path, body):
    return request("PATCH", path, body=body)


def delete(path):
    return request("DELETE", path)


def paged(path, params=None):
    """Iterate over every item of a paginated collection."""
    result = get(path, params)
    while True:
        yield from result.get("data", [])
        next_url = result.get("links", {}).get("next")
        if not next_url:
            return
        result = get(next_url)
