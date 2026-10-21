"""Validate real build-script naming, APK gates, remote publication and downloads."""

import importlib.util
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


SCRIPTS = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


client = load("apk_client", SCRIPTS / "publish_android_apk.py")
remote = load("apk_remote", SCRIPTS / "publish_android_apk_remote.py")
setup = load("apk_setup", SCRIPTS.parent / "deploy/setup_android_downloads.py")


class ApkValidationTests(unittest.TestCase):
    def inspect(self, *, package="com.bansheng.prod", debug=False, cert=None):
        badging = f"package: name='{package}' versionCode='8' versionName='0.6.1'\n"
        if debug:
            badging += "application-debuggable\n"
        cert = cert or client.RELEASE_CERT_SHA256
        with patch.object(client, "android_tool", side_effect=lambda name: name), patch.object(
            client, "run", side_effect=[SimpleNamespace(stdout=badging), SimpleNamespace(
                stdout=f"Signer #1 certificate SHA-256 digest: {cert}\n")]
        ):
            return client.inspect_apk(Path("fixture.apk"))

    def test_signed_prod_release(self):
        self.assertEqual(self.inspect(), "0.6.1+8")

    def test_debug_and_foreign_package_and_signature_rejected(self):
        for options in ({"debug": True}, {"package": "com.bansheng.dev"}, {"cert": "0" * 64}):
            with self.subTest(options=options), self.assertRaises(ValueError):
                self.inspect(**options)


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
                "qr_filename": "bansheng-0.6.1+8.qr.svg", "sha256": payload["sha256"],
                "qr_sha256": payload["qr_sha256"], "size_bytes": payload["size"],
                "url": "https://example.invalid/downloads/android/bansheng-0.6.1%2B8.apk",
                "qr_url": "https://example.invalid/downloads/android/bansheng-0.6.1%2B8.qr.svg"}

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

    def test_corrupt_qr_does_not_publish_apk_or_switch_latest(self):
        payload = self.prepare()
        (Path(payload["stage"]) / "qr.svg").write_text("corrupt")
        with self.assertRaisesRegex(ValueError, "QR code"):
            remote.main("publish", payload)
        self.assertEqual(list(self.public.iterdir()), [])


class PublicDownloadTests(unittest.TestCase):
    def test_failed_upload_cleans_staging_without_publishing(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "bansheng-0.6.1+8.apk"
            apk.write_bytes(b"release bytes")
            publisher = object.__new__(client.Publisher)
            publisher.host = "ubuntu@example.invalid"
            publisher.scp = ["scp"]
            publisher.base_url = "https://example.invalid/downloads/android"
            with patch.object(client, "inspect_apk", return_value="0.6.1+8"), patch.object(
                client, "run", side_effect=subprocess.CalledProcessError(1, ["scp"])
            ), patch.object(publisher, "remote", return_value={"stage": "/private/stage"}) as call:
                with self.assertRaises(subprocess.CalledProcessError):
                    publisher.publish(apk)
            self.assertEqual([c.args[0] for c in call.call_args_list], ["prepare", "cleanup"])
            self.assertFalse(apk.with_suffix(".apk.publish.json").exists())

    def test_receipt_only_after_correct_full_download_and_cleanup_on_failure(self):
        for corrupt, content_type, corrupt_qr in [(False, "application/vnd.android.package-archive", False),
                                      (True, "application/vnd.android.package-archive", False), (False, "text/html", False),
                                      (False, "application/vnd.android.package-archive", True)]:
            with self.subTest(corrupt=corrupt, content_type=content_type, corrupt_qr=corrupt_qr), tempfile.TemporaryDirectory() as directory:
                apk = Path(directory) / "bansheng-0.6.1+8.apk"
                apk.write_bytes(b"release bytes")
                publisher = object.__new__(client.Publisher)
                publisher.host = "ubuntu@example.invalid"
                publisher.scp = ["scp"]
                publisher.base_url = "https://example.invalid/downloads/android"
                calls = []
                assets = {}

                def remote_call(action, **kwargs):
                    calls.append(action)
                    if action == "activate": assets["release"] = kwargs["release"]
                    return {"stage": "/private/stage", "path": "/data/public.apk"}

                def run(args, **kwargs):
                    if args[0] == "scp":
                        if args[-2].endswith("qr.svg"): assets["qr"] = Path(args[-2]).read_bytes()
                        return SimpleNamespace(stdout="")
                    if "--output" in args:
                        is_qr = args[-1].endswith(".svg")
                        Path(args[args.index("--output") + 1]).write_bytes((b"corrupt QR" if corrupt_qr else assets["qr"]) if is_qr else b"wrong bytes" if corrupt else apk.read_bytes())
                        return SimpleNamespace(stdout="200\nimage/svg+xml" if is_qr else f"200\n{content_type}")
                    if args[-1].endswith("latest.json"): return SimpleNamespace(stdout=json.dumps(assets["release"]))
                    return SimpleNamespace(stdout=f"{client.sha256(apk)}  {apk.name}\n")

                with patch.object(client, "inspect_apk", return_value="0.6.1+8"), patch.object(
                    client, "run", side_effect=run
                ), patch.object(publisher, "remote", side_effect=remote_call):
                    if corrupt or content_type == "text/html" or corrupt_qr:
                        with self.assertRaisesRegex(ValueError, "download|QR code"):
                            publisher.publish(apk)
                    else:
                        publisher.publish(apk)
                success = not corrupt and content_type != "text/html" and not corrupt_qr
                self.assertEqual(calls, ["prepare", "publish", "activate", "cleanup"] if success else ["prepare", "publish", "cleanup"])
                self.assertEqual(apk.with_suffix(".apk.publish.json").exists(), success)


class QrCodeTests(unittest.TestCase):
    def test_qr_artifact_and_terminal_share_exact_download_url(self):
        import io
        url = "https://banshengcomp.com/downloads/android/bansheng-0.6.1%2B8.apk"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "qr.svg"
            qr = client.make_qr(url, path)
            self.assertEqual(b"".join(part.data for part in qr.data_list).decode(), url)
            self.assertIn("<svg", path.read_text())
            output = io.StringIO()
            qr.print_ascii(out=output, invert=True)
            self.assertIn("█", output.getvalue())


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
                                   ("prod", "debug", "bansheng-prod-0.6.1+8-debug.apk")]:
            with self.subTest(flavor=flavor, mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "scripts").mkdir()
                (root / "tools").mkdir()
                shutil.copy2(SCRIPTS / "build-android-apk.sh", root / "scripts")
                (root / "pubspec.yaml").write_text("version: 0.6.1+8\n")
                (root / "tools/git").write_text("#!/bin/sh\nexit 128\n")
                (root / "tools/flutter").write_text('''#!/usr/bin/env python3
import os,sys,time
from pathlib import Path
if sys.argv[1:3] == ['build','apk']:
 p=Path('build/app/outputs/flutter-apk') / ('app-'+os.environ['FLAVOR']+'-'+os.environ['BUILD_MODE']+'.apk')
 p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'fixture APK')
 os.utime(p,(time.time()+3,time.time()+3))
''')
                for tool in (root / "tools").iterdir():
                    tool.chmod(0o755)
                env = os.environ.copy()
                for key in ["BUILD_VERSION", "BUILD_NAME", "BUILD_NUMBER", "CLEAN"]:
                    env.pop(key, None)
                env.update(PATH=str(root / "tools") + os.pathsep + env["PATH"],
                           FLAVOR=flavor, BUILD_MODE=mode, INSTALL_ANDROID="0", OPEN_OUTPUT="0",
                           ANDROID_HOME=str(root / "missing-sdk"), ANDROID_SDK_ROOT=str(root / "missing-sdk"))
                result = subprocess.run(["bash", str(root / "scripts/build-android-apk.sh")], env=env,
                                        capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=20)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((root / "build/android" / name).read_bytes(), b"fixture APK")


if __name__ == "__main__":
    unittest.main()
