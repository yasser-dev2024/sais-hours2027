"""Developer-only Ed25519 lifetime-license generator for Horse Manager."""

from __future__ import annotations

import argparse
import base64
import ctypes
from ctypes import wintypes
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
)


APP_ID_DEFAULT = "com.abuammar.horseclub.mobile2026"
LICENSE_PREFIX = "HM1"
APP_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]{3,200}$")
DEVICE_ID_PATTERN = re.compile(r"^[A-Za-z0-9._:-]{8,128}$")


def _key_directory() -> Path:
    override = os.environ.get("HORSE_LICENSE_KEY_DIR")
    if override:
        return Path(override).expanduser().resolve()
    if os.name == "nt":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if not local_app_data:
            raise RuntimeError("LOCALAPPDATA is unavailable")
        return Path(local_app_data) / "HorseManagerLicenseGenerator"
    return Path.home() / ".config" / "horse-manager-license-generator"


def _private_key_path() -> Path:
    suffix = ".dpapi" if os.name == "nt" else ".pem"
    return _key_directory() / f"license_private_key{suffix}"


def _public_key_path() -> Path:
    return _key_directory() / "license_public_key.txt"


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


class _DataBlob(ctypes.Structure):
    _fields_ = [
        ("cbData", wintypes.DWORD),
        ("pbData", ctypes.POINTER(ctypes.c_ubyte)),
    ]


def _as_blob(data: bytes) -> tuple[_DataBlob, ctypes.Array[ctypes.c_ubyte]]:
    buffer = (ctypes.c_ubyte * len(data)).from_buffer_copy(data)
    return _DataBlob(len(data), buffer), buffer


def _dpapi_protect(data: bytes) -> bytes:
    crypt32 = ctypes.WinDLL("crypt32", use_last_error=True)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    crypt32.CryptProtectData.argtypes = [
        ctypes.POINTER(_DataBlob),
        wintypes.LPCWSTR,
        ctypes.POINTER(_DataBlob),
        ctypes.c_void_p,
        ctypes.c_void_p,
        wintypes.DWORD,
        ctypes.POINTER(_DataBlob),
    ]
    crypt32.CryptProtectData.restype = wintypes.BOOL
    kernel32.LocalFree.argtypes = [wintypes.HLOCAL]
    kernel32.LocalFree.restype = wintypes.HLOCAL
    input_blob, input_buffer = _as_blob(data)
    output_blob = _DataBlob()
    if not crypt32.CryptProtectData(
        ctypes.byref(input_blob),
        "Horse Manager Ed25519 private key",
        None,
        None,
        None,
        0x1,
        ctypes.byref(output_blob),
    ):
        raise ctypes.WinError(ctypes.get_last_error())
    del input_buffer
    try:
        return ctypes.string_at(output_blob.pbData, output_blob.cbData)
    finally:
        kernel32.LocalFree(output_blob.pbData)


def _dpapi_unprotect(data: bytes) -> bytes:
    crypt32 = ctypes.WinDLL("crypt32", use_last_error=True)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    crypt32.CryptUnprotectData.argtypes = [
        ctypes.POINTER(_DataBlob),
        ctypes.POINTER(wintypes.LPWSTR),
        ctypes.POINTER(_DataBlob),
        ctypes.c_void_p,
        ctypes.c_void_p,
        wintypes.DWORD,
        ctypes.POINTER(_DataBlob),
    ]
    crypt32.CryptUnprotectData.restype = wintypes.BOOL
    kernel32.LocalFree.argtypes = [wintypes.HLOCAL]
    kernel32.LocalFree.restype = wintypes.HLOCAL
    input_blob, input_buffer = _as_blob(data)
    output_blob = _DataBlob()
    if not crypt32.CryptUnprotectData(
        ctypes.byref(input_blob),
        None,
        None,
        None,
        None,
        0x1,
        ctypes.byref(output_blob),
    ):
        raise ctypes.WinError(ctypes.get_last_error())
    del input_buffer
    try:
        return ctypes.string_at(output_blob.pbData, output_blob.cbData)
    finally:
        kernel32.LocalFree(output_blob.pbData)


def _atomic_private_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary_name = tempfile.mkstemp(prefix="license-key-", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, stat.S_IREAD | stat.S_IWRITE)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _serialize_private_key(key: Ed25519PrivateKey) -> bytes:
    if os.name == "nt":
        raw = key.private_bytes(
            serialization.Encoding.Raw,
            serialization.PrivateFormat.Raw,
            serialization.NoEncryption(),
        )
        return _dpapi_protect(raw)
    password = os.environ.get("HORSE_LICENSE_KEY_PASSWORD")
    if not password:
        raise RuntimeError(
            "Set HORSE_LICENSE_KEY_PASSWORD before initializing the key on this OS",
        )
    return key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.BestAvailableEncryption(password.encode("utf-8")),
    )


def _load_private_key() -> Ed25519PrivateKey:
    path = _private_key_path()
    if not path.is_file():
        raise RuntimeError(f"Private key not found. Run init-key first: {path}")
    stored = path.read_bytes()
    if os.name == "nt":
        return Ed25519PrivateKey.from_private_bytes(_dpapi_unprotect(stored))
    password = os.environ.get("HORSE_LICENSE_KEY_PASSWORD")
    if not password:
        raise RuntimeError("Set HORSE_LICENSE_KEY_PASSWORD to unlock the key")
    loaded = serialization.load_pem_private_key(
        stored,
        password=password.encode("utf-8"),
    )
    if not isinstance(loaded, Ed25519PrivateKey):
        raise RuntimeError("The configured key is not Ed25519")
    return loaded


def _public_key_bytes(key: Ed25519PrivateKey) -> bytes:
    return key.public_key().public_bytes(
        serialization.Encoding.Raw,
        serialization.PublicFormat.Raw,
    )


def init_key() -> None:
    private_path = _private_key_path()
    if private_path.exists():
        raise RuntimeError(f"Private key already exists; refusing to overwrite: {private_path}")
    key = Ed25519PrivateKey.generate()
    _atomic_private_write(private_path, _serialize_private_key(key))
    public_key = _b64url(_public_key_bytes(key))
    public_path = _public_key_path()
    public_path.write_text(public_key + "\n", encoding="ascii")
    print(f"Private key stored outside the app: {private_path}")
    print(f"Public key: {public_key}")


def show_public_key() -> None:
    print(_b64url(_public_key_bytes(_load_private_key())))


def generate_license(app_id: str, device_id: str) -> None:
    app_id = app_id.strip()
    device_id = device_id.strip()
    if not APP_ID_PATTERN.fullmatch(app_id):
        raise ValueError("Invalid App ID")
    if not DEVICE_ID_PATTERN.fullmatch(device_id):
        raise ValueError("Invalid Device / Installation ID")
    payload = {
        "v": 1,
        "app_id": app_id,
        "installation_id": device_id,
        "license_type": "lifetime",
        "issued_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    payload_bytes = json.dumps(
        payload,
        ensure_ascii=True,
        separators=(",", ":"),
    ).encode("utf-8")
    signature = _load_private_key().sign(payload_bytes)
    print(f"{LICENSE_PREFIX}.{_b64url(payload_bytes)}.{_b64url(signature)}")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("init-key", help="Create the developer-only Ed25519 key")
    commands.add_parser("show-public-key", help="Print only the public key")
    generate = commands.add_parser("generate", help="Generate a lifetime license")
    generate.add_argument("--app-id", default=APP_ID_DEFAULT)
    generate.add_argument("--device-id", required=True)
    return parser


def main() -> int:
    args = _parser().parse_args()
    try:
        if args.command == "init-key":
            init_key()
        elif args.command == "show-public-key":
            show_public_key()
        else:
            generate_license(args.app_id, args.device_id)
        return 0
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
