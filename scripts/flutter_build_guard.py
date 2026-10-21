#!/usr/bin/env python3
"""Keep scripted Flutter builds and deliveries tied to the current local source."""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def digest_path(path: Path) -> str:
    digest = hashlib.sha256()
    paths = sorted(p for p in path.rglob('*') if p.is_file()) if path.is_dir() else [path]
    if not paths:
        raise ValueError(f'Build output is missing or empty: {path}')
    for item in paths:
        if path.is_dir():
            digest.update(item.relative_to(path).as_posix().encode() + b'\0')
        with item.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
    return digest.hexdigest()


def source_digest(root: Path | None = None) -> str:
    # Include untracked source too. Version-only changes after packaging are
    # intentional; dependency/configuration changes must invalidate the receipt.
    root = root or ROOT
    digest = hashlib.sha256()
    files = []
    for name in ('lib', 'assets', 'fonts'):
        files.extend(p for p in (root / name).rglob('*') if p.is_file())
    files.extend(p for p in (root / 'pubspec.yaml', root / 'pubspec.lock') if p.is_file())
    for path in sorted(files):
        data = path.read_bytes()
        if path.name == 'pubspec.yaml':
            data = re.sub(rb'^version:.*$', b'version: <build-argument>', data, flags=re.M)
        digest.update(path.relative_to(root).as_posix().encode() + b'\0')
        digest.update(hashlib.sha256(data).digest())
    if not files:
        raise ValueError('Flutter source is missing')
    return digest.hexdigest()


def receipt_path(artifact: Path) -> Path:
    return artifact.with_name(artifact.name + '.source.json')


def seal(artifact: Path, expected: str) -> None:
    if source_digest() != expected:
        raise ValueError('Source changed during the build. Rebuild before installing or publishing.')
    receipt = {'schema_version': 1, 'source_sha256': expected, 'artifact_sha256': digest_path(artifact)}
    receipt_path(artifact).write_text(json.dumps(receipt, indent=2) + '\n')
    print(f'Verified current source: {expected}\nArtifact SHA-256: {receipt["artifact_sha256"]}')


def verify(artifact: Path, *, snapshot: Path | None = None) -> None:
    try:
        receipt = json.loads(receipt_path(artifact).read_text())
    except (OSError, ValueError) as exc:
        raise ValueError('Build receipt missing or invalid. Rebuild with the current scripts.') from exc
    if not isinstance(receipt, dict):
        raise ValueError('Build receipt is invalid. Rebuild with the current scripts.')
    if receipt.get('schema_version') != 1 or receipt.get('source_sha256') != source_digest():
        raise ValueError('Artifact does not match current Dart source/assets/dependencies. Rebuild first.')
    if receipt.get('artifact_sha256') != digest_path(snapshot or artifact):
        raise ValueError('Artifact changed after build verification. Rebuild first.')


def validate_args(args: list[str]) -> None:
    for arg in args:
        option = arg.split('=', 1)[0]
        if option in ('--no-build', '--use-application-binary', '--config-only', '--build-dir') or arg == '--build=false':
            raise ValueError(f'{option} is not allowed: these scripts must build current source.')


def install_android(artifact: Path, device: str, package: str) -> None:
    verify(artifact)
    adb = ['adb', '-s', device]
    subprocess.run([*adb, 'install', '-r', str(artifact)], check=True, timeout=180)
    paths = subprocess.run([*adb, 'shell', 'pm', 'path', package], check=True,
                           capture_output=True, text=True, timeout=20).stdout.splitlines()
    if len(paths) != 1 or not re.fullmatch(r'package:/data/app/[A-Za-z0-9_~=/.-]+/base\.apk', paths[0]):
        raise ValueError(f'Cannot verify the installed base APK for {package}')
    installed = subprocess.run([*adb, 'exec-out', 'cat', paths[0].removeprefix('package:')],
                               check=True, capture_output=True, timeout=90).stdout
    if hashlib.sha256(installed).hexdigest() != digest_path(artifact):
        raise ValueError('Installed APK differs from the verified build. Refusing to launch it.')
    verify(artifact)
    print(f'Verified installed APK on {device}: {package}')


def locked(script: str, args: list[str]) -> int:
    validate_args(args)
    key = hashlib.sha256(str(ROOT).encode()).hexdigest()
    # Outside build/ and .dart_tool/: flutter clean removes both directories.
    with (Path(tempfile.gettempdir()) / f'companion-flutter-build-{key}.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ValueError('Another Flutter build/run script is using this checkout. Finish it first.') from exc
        env = dict(os.environ, COMPANION_BUILD_SCRIPT=str(Path(script).resolve()))
        # Keep the lock alive in the shell too, even if this parent is killed
        # while its build process is still writing output.
        return subprocess.call(['/bin/bash', script, *args], env=env, pass_fds=(lock.fileno(),))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('lock', 'fingerprint', 'assert-clean', 'seal', 'verify', 'verify-snapshot', 'ios-identity', 'install-android'))
    parser.add_argument('args', nargs=argparse.REMAINDER)
    options = parser.parse_args()
    try:
        if options.action == 'lock':
            return locked(options.args[0], options.args[1:])
        if options.action == 'fingerprint':
            print(source_digest())
        elif options.action == 'assert-clean':
            for path in (ROOT / 'build', ROOT / '.dart_tool/flutter_build'):
                if path.exists():
                    raise ValueError(f'flutter clean did not remove old output: {path}')
        elif options.action == 'seal':
            seal(Path(options.args[0]), options.args[1])
        elif options.action == 'verify':
            verify(Path(options.args[0]))
        elif options.action == 'verify-snapshot':
            verify(Path(options.args[0]), snapshot=Path(options.args[1]))
        elif options.action == 'install-android':
            install_android(Path(options.args[0]), options.args[1], options.args[2])
        elif options.action == 'ios-identity':
            with (Path(options.args[0]) / 'Info.plist').open('rb') as stream:
                actual = plistlib.load(stream).get('CFBundleIdentifier')
            if actual != options.args[1]:
                raise ValueError(f'Built iOS bundle is {actual}, expected {options.args[1]}. Refusing to launch another app.')
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        print(f'Flutter build verification failed: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
