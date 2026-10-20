"""Executed via SSH stdin; public artifacts and private staging stay on /dev/vdb."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


DATA_DISK = Path("/mnt/datadisk0")
ROOT = DATA_DISK / "companion/downloads"
PUBLIC = ROOT / "android"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_storage():
    mount = subprocess.run(["findmnt", "-n", "-o", "TARGET", "-T", str(ROOT)],
                           text=True, capture_output=True, check=True, timeout=10).stdout.strip()
    if mount != str(DATA_DISK) or ROOT.resolve() != ROOT or PUBLIC.resolve() != PUBLIC:
        raise ValueError("Refusing publication: downloads must reside on /mnt/datadisk0, without symlinks.")
    if not PUBLIC.is_dir():
        raise ValueError("Downloads directory missing; install deploy/android-downloads.nginx.conf first.")


def stage_path(value):
    path = Path(value)
    if path.parent != ROOT or not re.fullmatch(r"\.android-upload-[a-zA-Z0-9_]+", path.name) or path.resolve() != path:
        raise ValueError("Invalid staging path.")
    return path


def publish(payload):
    name = payload["name"]
    if not re.fullmatch(r"bansheng-[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+\.apk", name):
        raise ValueError("Invalid APK filename.")
    digest = payload["sha256"]
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("Invalid SHA-256.")
    stage = stage_path(payload["stage"])
    source = stage / "upload.apk"
    if source.is_symlink() or source.stat().st_size != payload["size"] or sha256(source) != digest:
        raise ValueError("Uploaded APK checksum/size mismatch.")
    destination = PUBLIC / name
    # Lock covers duplicate checks and publication across concurrent uploaders.
    with (ROOT / ".android-publish.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ValueError("Another APK publication is in progress; retry when it finishes.") from exc
        if destination.is_symlink():
            raise ValueError("Refusing a symlink destination.")
        if destination.exists():
            if sha256(destination) != digest:
                raise ValueError("This version already exists with different contents; bump the build number.")
        else:
            os.chmod(source, 0o644)
            os.link(source, destination)  # Atomic visibility; an APK is never served half uploaded.
        checksum = stage / "checksum"
        checksum.write_text(f"{digest}  {name}\n")
        os.chmod(checksum, 0o644)
        os.replace(checksum, PUBLIC / f"{name}.sha256")
    return {"path": str(destination), "sha256": digest}


def main(action, payload):
    check_storage()
    if action == "prepare":
        size = payload["size"]
        if not isinstance(size, int) or size <= 0 or size > 1024 * 1024 * 1024:
            raise ValueError("APK size must be between 1 byte and 1 GiB.")
        if shutil.disk_usage(ROOT).free < size * 2 + 100 * 1024 * 1024:
            raise ValueError("Insufficient free space on data disk.")
        return {"stage": tempfile.mkdtemp(prefix=".android-upload-", dir=ROOT)}
    if action == "publish":
        return publish(payload)
    if action == "cleanup":
        shutil.rmtree(stage_path(payload["stage"]), ignore_errors=False)
        return {"cleaned": True}
    raise ValueError("Unknown action.")


if __name__ == "__main__":
    try:
        print(json.dumps(main(sys.argv[1], json.loads(sys.argv[2]))))
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"Publication refused: {exc}", file=sys.stderr)
        sys.exit(1)
