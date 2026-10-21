"""Validate real build-script naming, APK gates, remote publication and downloads."""

import importlib.util
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
import zipfile
from test_android_aot import elf_fixture
from unittest.mock import patch


SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


remote = load("apk_remote", SCRIPTS / "publish_android_apk_remote.py")
setup = load("apk_setup", SCRIPTS.parent / "deploy/setup_android_downloads.py")


class RemotePublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.disk = Path(self.temp.name).resolve()
        self.root = self.disk / "companion/downloads"
        self.public = self.root / "android"
        self.public.mkdir(parents=True)
        for attr, value in [("DATA_DISK", self.disk), ("ROOT", self.root), ("PUBLIC", self.public)]:
            p = patch.object(remote, attr, value)
            p.start()
            self.addCleanup(p.stop)
        p = patch.object(remote.subprocess, "run", return_value=SimpleNamespace(stdout=str(self.disk)))
        self.mount = p.start()
        self.addCleanup(p.stop)

    def prepare(self, contents=b"signed APK"):
        stage = Path(remote.main("prepare", {"size": len(contents)})["stage"])
        (stage / "upload.apk").write_bytes(contents)
        (stage / "qr.svg").write_bytes(b"<svg>QR fixture</svg>")
        return {"stage": str(stage), "name": "bansheng-0.6.1+8.apk",
                "sha256": remote.sha256(stage / "upload.apk"), "size": len(contents),
                "qr_sha256": remote.sha256(stage / "qr.svg")}

    def test_publish_checksum_idempotence_and_cleanup(self):
        payload = self.prepare()
        self.assertEqual(Path(payload["stage"]).stat().st_mode & 0o777, 0o700)
        result = remote.main("publish", payload)
        self.assertEqual(Path(result["path"]).read_bytes(), b"signed APK")
        self.assertEqual(Path(result["path"]).stat().st_mode & 0o777, 0o644)
        self.assertEqual(Path(result["path"] + ".sha256").read_text(),
                         f'{payload["sha256"]}  {payload["name"]}\n')
        remote.main("publish", payload)
        remote.main("cleanup", payload)
        self.assertFalse(Path(payload["stage"]).exists())
        self.assertTrue(Path(result["path"]).exists())

    def test_same_version_cannot_be_overwritten(self):
        first = self.prepare()
        remote.main("publish", first)
        second = self.prepare(b"a different release")
        with self.assertRaisesRegex(ValueError, "different contents"):
            remote.main("publish", second)
        self.assertEqual((self.public / first["name"]).read_bytes(), b"signed APK")

    def test_corruption_rejected_before_publication(self):
        payload = self.prepare()
        (Path(payload["stage"]) / "upload.apk").write_bytes(b"corrupted!")
        with self.assertRaisesRegex(ValueError, "mismatch"):
            remote.main("publish", payload)
        self.assertEqual(list(self.public.iterdir()), [])

    def test_system_disk_and_path_traversal_rejected(self):
        self.mount.return_value.stdout = "/"
        with self.assertRaises(ValueError):
            remote.main("prepare", {"size": 10})
        for value in [str(self.root), str(self.root / "../android-upload-abc"), str(self.root / "android")]:
            with self.assertRaises(ValueError):
                remote.stage_path(value)

    def test_symlink_destination_rejected(self):
        payload = self.prepare()
        target = self.root / "unrelated"
        target.write_text("do not change")
        (self.public / payload["name"]).symlink_to(target)
        with self.assertRaisesRegex(ValueError, "symlink"):
            remote.main("publish", payload)
        self.assertEqual(target.read_text(), "do not change")

    def test_insufficient_space_rejected(self):
        with patch.object(remote.shutil, "disk_usage", return_value=SimpleNamespace(free=0)):
            with self.assertRaisesRegex(ValueError, "free space"):
                remote.main("prepare", {"size": 10})

    def test_concurrent_publisher_fails_without_waiting(self):
        payload = self.prepare()
        with (self.root / ".android-publish.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaisesRegex(ValueError, "in progress"):
                remote.main("publish", payload)
        self.assertEqual(list(self.public.iterdir()), [])

    def release(self, payload):
        return {"schema_version": 1, "version": "0.6.1+8", "filename": payload["name"],
                "qr_filename": "bansheng-latest.qr.svg", "sha256": payload["sha256"],
                "qr_sha256": payload["qr_sha256"], "size_bytes": payload["size"],
                "url": "https://example.invalid/downloads/android/bansheng-0.6.1%2B8.apk",
                "qr_url": "https://example.invalid/downloads/android/bansheng-latest.qr.svg",
                "download_url": "https://example.invalid/downloads/android/bansheng-latest.apk"}

    def test_activation_requires_complete_pair_and_preserves_newer_latest(self):
        payload = self.prepare()
        release = self.release(payload)
        with self.assertRaises(OSError):
            remote.main("activate", {"release": release})
        self.assertFalse((self.public / "latest.json").exists())
        remote.main("publish", payload)
        remote.main("activate", {"release": release})
        self.assertEqual(json.loads((self.public / "latest.json").read_text())["qr_sha256"], payload["qr_sha256"])
        newer = {**release, "version": "0.6.1+9"}
        (self.public / "latest.json").write_text(json.dumps(newer))
        with self.assertRaisesRegex(ValueError, "older release"):
            remote.main("activate", {"release": release})
        self.assertEqual(json.loads((self.public / "latest.json").read_text())["version"], "0.6.1+9")

    def test_stable_download_switches_versions_without_changing_qr(self):
        first = self.prepare()
        remote.main("publish", first)
        remote.main("activate", {"release": self.release(first)})
        pointer = self.public / "bansheng-latest.apk"
        qr = self.public / "bansheng-latest.qr.svg"
        qr_before = qr.read_bytes()
        self.assertEqual(pointer.read_bytes(), b"signed APK")
        second = self.prepare(b"new release")
        second["name"] = "bansheng-0.6.1+9.apk"
        remote.main("publish", second)
        # Upload alone must not change the active download.
        self.assertEqual(pointer.read_bytes(), b"signed APK")
        newer = {**self.release(second), "version": "0.6.1+9"}
        remote.main("activate", {"release": newer})
        self.assertEqual(pointer.read_bytes(), b"new release")
        self.assertEqual(os.readlink(pointer), second["name"])
        self.assertEqual(qr.read_bytes(), qr_before)
        self.assertEqual(json.loads((self.public / "latest.json").read_text())["version"], "0.6.1+9")
        with self.assertRaisesRegex(ValueError, "older release"):
            remote.main("activate", {"release": self.release(first)})
        self.assertEqual(pointer.read_bytes(), b"new release")

    def test_stable_qr_cannot_be_silently_replaced(self):
        first = self.prepare()
        remote.main("publish", first)
        second = self.prepare(b"new release")
        second["name"] = "bansheng-0.6.1+9.apk"
        (Path(second["stage"]) / "qr.svg").write_bytes(b"different QR")
        second["qr_sha256"] = remote.sha256(Path(second["stage"]) / "qr.svg")
        with self.assertRaisesRegex(ValueError, "different contents"):
            remote.main("publish", second)
        self.assertFalse((self.public / second["name"]).exists())

    def test_corrupt_qr_does_not_publish_apk_or_switch_latest(self):
        payload = self.prepare()
        (Path(payload["stage"]) / "qr.svg").write_text("corrupt")
        with self.assertRaisesRegex(ValueError, "QR code"):
            remote.main("publish", payload)
        self.assertEqual(list(self.public.iterdir()), [])


class NginxSetupTests(unittest.TestCase):
    def test_existing_site_preserved_and_setup_idempotent(self):
        original = ("server {\n    server_name banshengcomp.com www.banshengcomp.com;\n"
                    "    root /app/companion-web/dist;\n    location /acme/ {\n"
                    "        root /app/companion-web/dist;\n    }\n}\n")
        changed = setup.add_include(original)
        self.assertEqual(changed.replace(setup.INCLUDE + "\n\n", ""), original)
        self.assertEqual(setup.add_include(changed), changed)

    def test_unexpected_site_rejected(self):
        with self.assertRaises(ValueError):
            setup.add_include("server { root /unrelated; }")


class BuildNamingTests(unittest.TestCase):
    def test_actual_script_names_prod_release_and_isolates_other_builds(self):
        for flavor, mode, name in [("prod", "release", "bansheng-0.6.1+8.apk"),
                                   ("dev", "release", "bansheng-dev-0.6.1+8.apk"),
                                   ("prod", "debug", "bansheng-prod-0.6.1+8-debug.apk"),
                                   ("prod", "release", None)]:
            with self.subTest(flavor=flavor, mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "scripts").mkdir()
                (root / "tools").mkdir()
                shutil.copy2(SCRIPTS / "build-android-apk.sh", root / "scripts")
                shutil.copy2(SCRIPTS / "verify_android_aot.py", root / "scripts")
                for helper in ("fresh-build.sh", "flutter_build_guard.py"):
                    shutil.copy2(SCRIPTS / helper, root / "scripts")
                (root / "fixture.so").write_bytes(elf_fixture())
                (root / "pubspec.yaml").write_text("version: 0.6.1+8\n")
                (root / "tools/git").write_text("#!/bin/sh\nexit 128\n")
                (root / "tools/flutter").write_text('''#!/usr/bin/env python3
import os,sys,time,zipfile
from pathlib import Path
if sys.argv[1:3] == ['build','apk']:
 p=Path('build/app/outputs/flutter-apk') / ('app-'+os.environ['FLAVOR']+'-'+os.environ['BUILD_MODE']+'.apk')
 p.parent.mkdir(parents=True,exist_ok=True)
 runtime=Path('fixture.so').read_bytes()
 with zipfile.ZipFile(p,'w') as z:z.writestr('lib/arm64-v8a/libapp.so',runtime.replace(b'current-code',b'old-old-code') if os.environ.get('STALE_AOT') == '1' else runtime)
 jni=Path('build/app/intermediates/flutter/'+os.environ['FLAVOR']+'Release/jniLibs/arm64-v8a/libapp.so')
 jni.parent.mkdir(parents=True,exist_ok=True);jni.write_bytes(runtime)
 os.utime(p,(time.time()+3,time.time()+3))
''')
                for tool in (root / "tools").iterdir():
                    tool.chmod(0o755)
                env = os.environ.copy()
                for key in ["BUILD_VERSION", "BUILD_NAME", "BUILD_NUMBER", "CLEAN"]:
                    env.pop(key, None)
                env.update(PATH=str(root / "tools") + os.pathsep + env["PATH"],
                           FLAVOR=flavor, BUILD_MODE=mode, INSTALL_ANDROID="0", OPEN_OUTPUT="0", STALE_AOT="1" if name is None else "0",
                           ANDROID_HOME=str(root / "missing-sdk"), ANDROID_SDK_ROOT=str(root / "missing-sdk"))
                result = subprocess.run(["bash", str(root / "scripts/build-android-apk.sh")], env=env,
                                        capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=20)
                if name is None:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("stale Flutter AOT", result.stderr)
                    self.assertFalse((root / "build/android").exists())
                    continue
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                with zipfile.ZipFile(root / "build/android" / name) as archive:
                    self.assertEqual(archive.read("lib/arm64-v8a/libapp.so"), elf_fixture())


if __name__ == "__main__":
    unittest.main()
