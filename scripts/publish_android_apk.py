"""Publish a signed production APK over SSH, then verify its HTTPS download."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import quote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
REMOTE_SCRIPT = Path(__file__).with_name("publish_android_apk_remote.py")
RELEASE_CERT_SHA256 = "9d9845f19d19dd953edcd1ddd08628a9e5374f1dad12c40df86e61c48243a658"
VERSION_PATTERN = r"[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+"


def run(args, *, timeout=60, **kwargs):
    return subprocess.run(args, check=True, text=True, timeout=timeout, **kwargs)


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def android_tool(name):
    sdk = Path(os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
               or Path.home() / "Library/Android/sdk")
    candidates = list((sdk / "build-tools").glob(f"*/{name}"))
    candidates.sort(key=lambda p: tuple(int(n) for n in re.findall(r"\d+", p.parent.name)))
    if not candidates:
        raise ValueError(f"Android SDK {name} is required (set ANDROID_HOME).")
    return str(candidates[-1])


def inspect_apk(apk):
    badging = run([android_tool("aapt"), "dump", "badging", str(apk)], capture_output=True).stdout
    package = re.search(r"^package: name='([^']+)' versionCode='([0-9]+)' versionName='([^']+)'", badging, re.M)
    if not package or package[1] != "com.bansheng.prod":
        raise ValueError("Only com.bansheng.prod APKs may be published.")
    if "application-debuggable" in badging:
        raise ValueError("Debuggable APKs cannot be published; build prod release first.")
    version = f"{package[3]}+{package[2]}"
    if not re.fullmatch(VERSION_PATTERN, version):
        raise ValueError(f"Invalid APK version: {version}")
    certs = run([android_tool("apksigner"), "verify", "--print-certs", str(apk)],
                capture_output=True).stdout
    signatures = re.findall(r"^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]{64})$", certs, re.M)
    if [s.lower() for s in signatures] != [RELEASE_CERT_SHA256]:
        raise ValueError("APK is not signed with the approved Bansheng release certificate.")
    return version


def default_apk():
    version = re.search(rf"^version:\s*({VERSION_PATTERN})\s*$", (ROOT / "pubspec.yaml").read_text(), re.M)
    if not version:
        raise ValueError("Cannot read the current pubspec.yaml version.")
    return ROOT / "build/android" / f"bansheng-{version[1]}.apk"


class Publisher:
    def __init__(self):
        self.host = os.environ.get("APK_SSH_HOST", "ubuntu@106.52.115.80")
        if not re.fullmatch(r"[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+", self.host):
            raise ValueError("APK_SSH_HOST must be user@hostname.")
        port = os.environ.get("APK_SSH_PORT", "22")
        if not port.isdigit() or not 1 <= int(port) <= 65535:
            raise ValueError("Invalid APK_SSH_PORT.")
        key = Path(os.environ.get("APK_SSH_KEY", str(Path.home() / ".ssh/companion_tencent"))).expanduser()
        if not key.is_file():
            raise ValueError(f"SSH identity file missing: {key}")
        self.options = ["-i", str(key), "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
                        "-o", "ConnectTimeout=15", "-o", "ServerAliveInterval=15",
                        "-o", "ServerAliveCountMax=3"]
        self.ssh = ["ssh", *self.options, "-p", port, self.host]
        self.scp = ["scp", *self.options, "-P", port]
        self.base_url = os.environ.get("APK_PUBLIC_BASE_URL", "https://banshengcomp.com/downloads/android").rstrip("/")
        parsed = urlsplit(self.base_url)
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError("APK_PUBLIC_BASE_URL must be an HTTPS directory URL without credentials/query/fragment.")

    def remote(self, action, **payload):
        command = shlex.join(["python3", "-", action, json.dumps(payload, separators=(",", ":"))])
        result = run([*self.ssh, command], input=REMOTE_SCRIPT.read_text(), capture_output=True, timeout=90)
        return json.loads(result.stdout)

    def publish(self, apk):
        stage = None
        with tempfile.TemporaryDirectory(prefix="bansheng-apk-publish-") as directory:
            snapshot = Path(directory) / "upload.apk"
            shutil.copyfile(apk, snapshot)
            version = inspect_apk(snapshot)
            name = f"bansheng-{version}.apk"
            if apk.name != name:
                raise ValueError(f"APK filename must match its embedded version: {name}")
            digest = sha256(snapshot)
            size = snapshot.stat().st_size
            url = f"{self.base_url}/{quote(name)}"
            print(f"Verified prod release {version}, {size:,} bytes, SHA-256 {digest}", flush=True)
            try:
                stage = self.remote("prepare", size=size)["stage"]
                print("Uploading to the Tencent data disk…", flush=True)
                run([*self.scp, str(snapshot), f"{self.host}:{stage}/upload.apk"], timeout=900)
                result = self.remote("publish", stage=stage, name=name, sha256=digest, size=size)
                print("Verifying full HTTPS download…", flush=True)
                download = Path(directory) / "download.apk"
                response = run(["curl", "--fail", "--silent", "--show-error", "--proto", "=https",
                                "--connect-timeout", "15", "--max-time", "900", "--output", str(download),
                                "--write-out", "%{http_code}\n%{content_type}",
                                f"{url}?sha256={digest}"], capture_output=True, timeout=920).stdout.splitlines()
                if response != ["200", "application/vnd.android.package-archive"] or sha256(download) != digest:
                    raise ValueError("Public APK download failed status/MIME/SHA-256 verification.")
                checksum = run(["curl", "--fail", "--silent", "--show-error", "--proto", "=https",
                                "--connect-timeout", "15", "--max-time", "30", f"{url}.sha256"],
                               capture_output=True).stdout
                if checksum != f"{digest}  {name}\n":
                    raise ValueError("Public checksum file does not match the APK.")
                receipt = {"version": version, "package": "com.bansheng.prod", "url": url,
                           "sha256": digest, "size_bytes": size, "certificate_sha256": RELEASE_CERT_SHA256,
                           "remote_path": result["path"], "verified_at": datetime.now(timezone.utc).isoformat()}
                receipt_path = apk.with_suffix(".apk.publish.json")
                receipt_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
                print(f"Published and verified: {url}\nReceipt: {receipt_path}", flush=True)
                return receipt
            finally:
                if stage:
                    try:
                        self.remote("cleanup", stage=stage)
                    except (subprocess.SubprocessError, ValueError) as exc:
                        print(f"Warning: staging cleanup failed: {exc}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", nargs="?", type=Path, help="Defaults to build/android/bansheng-<pubspec version>.apk")
    args = parser.parse_args()
    try:
        apk = (args.apk or default_apk()).resolve()
        if not apk.is_file():
            raise ValueError(f"APK not found: {apk}. Run scripts/build-android-apk.sh first.")
        Publisher().publish(apk)
    except subprocess.CalledProcessError as exc:
        print(f"Publish failed: {exc}\n{exc.stderr or ''}", file=sys.stderr)
        return 1
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"Publish failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
