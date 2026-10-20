"""One-time host setup, run as root with the Nginx snippet supplied on argv.

Routine APK publication never needs sudo or a server restart.
"""

import base64
from datetime import datetime, timezone
import os
from pathlib import Path
import pwd
import re
import subprocess
import sys
import tempfile


INCLUDE = "    include /etc/nginx/snippets/companion-android-downloads.conf;"


def add_include(config):
    if INCLUDE in config.splitlines():
        return config
    anchor = "    root /app/companion-web/dist;"
    pattern = "^" + re.escape(anchor) + "$"
    if len(re.findall(pattern, config, re.M)) != 1 or "server_name banshengcomp.com www.banshengcomp.com;" not in config:
        raise ValueError("Unexpected existing site; inspect before changing Nginx.")
    return re.sub(pattern, INCLUDE + "\n\n" + anchor, config, flags=re.M)


def atomic_write(path, contents):
    fd, name = tempfile.mkstemp(prefix=".android-nginx-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(contents)
        os.chmod(name, 0o644)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def main(snippet_contents):
    if os.geteuid() != 0:
        raise ValueError("Run this one-time setup with sudo.")
    mount = subprocess.run(["findmnt", "-n", "-o", "TARGET", "-T", "/mnt/datadisk0"],
                           check=True, capture_output=True, text=True, timeout=10).stdout.strip()
    if mount != "/mnt/datadisk0":
        raise ValueError("The data disk is not mounted.")
    site = Path("/etc/nginx/sites-enabled/banshengcomp.com").resolve(strict=True)
    snippet = Path("/etc/nginx/snippets/companion-android-downloads.conf")
    original = site.read_text()
    updated = add_include(original)
    old_snippet = snippet.read_text() if snippet.exists() else None
    owner = pwd.getpwnam("ubuntu")
    downloads = Path("/mnt/datadisk0/companion/downloads")
    for directory in (downloads, downloads / "android"):
        if directory.resolve() != directory:
            raise ValueError("Download paths must not be symlinks.")
        directory.mkdir(exist_ok=True)
        os.chown(directory, owner.pw_uid, owner.pw_gid)
        os.chmod(directory, 0o755)
    if original == updated and old_snippet == snippet_contents:
        subprocess.run(["nginx", "-t"], check=True, timeout=15)
        print("Android download route already configured.")
        return
    backup = downloads / ".nginx-backups" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    backup.mkdir(parents=True, mode=0o700)
    os.chmod(backup.parent, 0o700)
    (backup / "site.conf").write_text(original)
    if old_snippet is not None:
        (backup / "snippet.conf").write_text(old_snippet)
    snippet.parent.mkdir(exist_ok=True)
    try:
        atomic_write(snippet, snippet_contents)
        atomic_write(site, updated)
        subprocess.run(["nginx", "-t"], check=True, timeout=15)
        subprocess.run(["systemctl", "reload", "nginx"], check=True, timeout=30)
    except Exception:
        atomic_write(site, original)
        if old_snippet is None:
            snippet.unlink(missing_ok=True)
        else:
            atomic_write(snippet, old_snippet)
        subprocess.run(["nginx", "-t"], check=True, timeout=15)
        subprocess.run(["systemctl", "reload", "nginx"], check=True, timeout=30)
        raise
    print(f"Android HTTPS downloads configured on the data disk. Backup: {backup}")


if __name__ == "__main__":
    main(base64.b64decode(sys.argv[1], validate=True).decode("utf-8"))
