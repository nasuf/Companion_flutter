"""Exercise the real Bash publisher with isolated SDK/SSH/SCP/HTTPS tools."""
import hashlib
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import flutter_build_guard as guard

CERT = '9d9845f19d19dd953edcd1ddd08628a9e5374f1dad12c40df86e61c48243a658'
STAGE = '/mnt/datadisk0/companion/downloads/.android-upload-fixture123'

TOOLS = r'''#!/usr/bin/env python3
import hashlib, json, os, shlex, shutil, sys
from pathlib import Path
root = Path(os.environ['PUBLISH_FIXTURE_ROOT'])
tool, args = Path(sys.argv[0]).name, sys.argv[1:]
with (root / 'calls.jsonl').open('a') as out:
    out.write(json.dumps([tool, *args]) + '\n')
def enabled(key): return os.environ.get(key) == '1'
if tool == 'aapt':
    assert Path(sys.argv[0]).parent.name == '37.0.0'
    package = 'com.bansheng.dev' if enabled('FOREIGN_PACKAGE') else 'com.bansheng.prod'
    print(f"package: name='{package}' versionCode='8' versionName='0.6.1'")
    if enabled('DEBUG_APK'): print('application-debuggable')
elif tool == 'apksigner':
    assert Path(sys.argv[0]).parent.name == '37.0.0'
    certificate = '0'*64 if enabled('WRONG_CERT') else os.environ['CERT']
    print('Signer #1 certificate SHA-256 digest: ' + certificate)
    if enabled('MULTIPLE_SIGNERS'): print('Signer #2 certificate SHA-256 digest: ' + certificate)
elif tool == 'ssh':
    words = shlex.split(args[-1])
    assert words[:2] == ['python3', '-']
    action, payload = words[2], json.loads(words[3])
    assert sys.stdin.read() == (root / 'scripts/publish_android_apk_remote.py').read_text()
    assert 'StrictHostKeyChecking=yes' in args
    with (root / 'actions.jsonl').open('a') as out: out.write(json.dumps([action, payload]) + '\n')
    if action == 'prepare':
        if enabled('FAIL_PREPARE'): sys.exit(27)
        print(json.dumps({'stage': '/unsafe/path' if enabled('INVALID_STAGE') else os.environ['STAGE']}))
    elif action == 'publish':
        assert payload['stage'] == os.environ['STAGE']
        assert hashlib.sha256((root / 'upload.apk').read_bytes()).hexdigest() == payload['sha256']
        if enabled('FAIL_PUBLISH'): sys.exit(28)
        print(json.dumps({'path': '/mnt/datadisk0/companion/downloads/android/' + payload['name']}))
    elif action == 'activate':
        if enabled('FAIL_ACTIVATE'): sys.exit(31)
        (root / 'activated.json').write_text(json.dumps(payload['release']))
        print(json.dumps(payload['release']))
    elif action == 'cleanup':
        (root / 'cleaned').write_text(payload['stage'])
        if enabled('FAIL_CLEANUP'): sys.exit(32)
        print('{"cleaned":true}')
    else: raise RuntimeError(action)
elif tool == 'scp':
    source = Path(args[-2])
    if enabled('FAIL_UPLOAD') or (enabled('FAIL_QR_UPLOAD') and source.name == 'qr.svg'): sys.exit(29)
    assert args[-1].split(':', 1)[1].startswith(os.environ['STAGE'] + '/')
    shutil.copyfile(source, root / source.name)
    if enabled('CHANGE_SOURCE_ON_UPLOAD'):
        (root / 'lib/main.dart').write_text('source changed during upload')
elif tool == 'curl':
    url = args[-1]
    destination = Path(args[args.index('--output') + 1])
    if enabled('FAIL_DOWNLOAD'): sys.exit(22)
    if url.endswith('latest.json'):
        release = json.loads((root / 'activated.json').read_text())
        if enabled('WRONG_LATEST'): release['sha256'] = '0' * 64
        destination.write_text(json.dumps(release))
        mime = 'application/json; charset=utf-8'
    elif url.endswith('.sha256'):
        digest = hashlib.sha256((root / 'upload.apk').read_bytes()).hexdigest()
        destination.write_text(f'{digest}  bansheng-0.6.1+8.apk\n' if not enabled('WRONG_CHECKSUM') else 'wrong checksum')
        mime = 'text/plain; charset=utf-8'
    elif url.endswith('.svg'):
        destination.write_bytes(b'corrupt QR' if enabled('CORRUPT_QR') else (root / 'qr.svg').read_bytes())
        mime = 'image/svg+xml'
    else:
        corrupt = enabled('CORRUPT_APK') or (enabled('CORRUPT_STABLE') and url.endswith('/bansheng-latest.apk'))
        destination.write_bytes(b'corrupt APK' if corrupt else (root / 'upload.apk').read_bytes())
        mime = 'text/html' if enabled('WRONG_MIME') else 'application/vnd.android.package-archive'
        if enabled('CHANGE_SOURCE_ON_DOWNLOAD'):
            (root / 'lib/main.dart').write_text('source changed before release activation')
    print(('404' if enabled('WRONG_STATUS') else '200') + '\n' + mime, end='')
else: raise RuntimeError(tool)
'''


class ShellPublisherTests(unittest.TestCase):
    def fixture(self, *, extra=(), use_default=False, **options):
        with tempfile.TemporaryDirectory(prefix='apk-shell-') as directory:
            root = Path(directory) / 'project with spaces'
            for folder in ('scripts', 'lib', 'tools', 'temporary files', 'build/android/.publish-venv/bin'):
                (root / folder).mkdir(parents=True)
            for name in ('publish-android-apk.sh', 'fresh-build.sh', 'flutter_build_guard.py', 'publish_android_apk_remote.py'):
                shutil.copy2(SCRIPTS / name, root / 'scripts')
            (root / 'lib/main.dart').write_text('current application source')
            (root / 'pubspec.yaml').write_text('version: 0.6.1+8\n')
            apk = root / 'build/android/bansheng-0.6.1+8.apk'
            apk.write_bytes(b'current release APK fixture')
            with patch.object(guard, 'ROOT', root), redirect_stdout(io.StringIO()):
                guard.seal(apk, guard.source_digest())
            if options.pop('MISSING_RECEIPT', '0') == '1': guard.receipt_path(apk).unlink()
            if options.pop('REPLACED_APK', '0') == '1': apk.write_bytes(b'replaced package')
            if options.pop('STALE_SOURCE', '0') == '1': (root / 'lib/main.dart').write_text('new source after build')
            if options.pop('WRONG_FILENAME', '0') == '1':
                renamed = apk.with_name('incorrect.apk')
                guard.receipt_path(apk).rename(guard.receipt_path(renamed))
                apk.rename(renamed)
                apk = renamed
            sdk = root / 'Android SDK'
            for version in ('9.0.0', '37.0.0'):
                for tool in ('aapt', 'apksigner'):
                    path = sdk / 'build-tools' / version / tool
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(TOOLS)
                    path.chmod(0o755)
            for tool in ('ssh', 'scp', 'curl'):
                path = root / 'tools' / tool
                path.write_text(TOOLS)
                path.chmod(0o755)
            qr_python = root / 'build/android/.publish-venv/bin/python'
            qr_python.write_text('#!/bin/sh\nexec ' + shlex.quote(sys.executable) + ' "$@"\n')
            qr_python.chmod(0o755)
            key = root / 'identity key'
            key.write_text('fixture key contents never sent to tools')
            env = {k: v for k, v in os.environ.items() if not k.startswith(('APK_', 'COMPANION_BUILD_'))}
            env.update(PATH=str(root / 'tools') + os.pathsep + os.environ['PATH'],
                       PUBLISH_FIXTURE_ROOT=str(root), CERT=CERT, STAGE=STAGE,
                       TMPDIR=str(root / 'temporary files'), ANDROID_HOME=str(sdk),
                       APK_SSH_HOST='ubuntu@example.invalid', APK_SSH_KEY=str(key),
                       APK_PUBLIC_BASE_URL="https://example.invalid/a'b/downloads/android")
            env.update(options)
            result = subprocess.run(['/bin/bash', str(root / 'scripts/publish-android-apk.sh'),
                                     *([] if use_default else [str(apk)]), *extra], cwd=directory, env=env,
                                    capture_output=True, text=True, timeout=25)
            def records(name):
                path = root / name
                return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []
            receipt = Path(str(apk) + '.publish.json')
            receipt_data = json.loads(receipt.read_text()) if receipt.exists() else None
            qr = root / 'qr.svg'
            qr_bytes = qr.read_bytes() if qr.exists() else None
            self.assertFalse(any(p.name.startswith('bansheng-apk-publish.')
                                 for p in (root / 'temporary files').iterdir()))
            return result, records('actions.jsonl'), records('calls.jsonl'), receipt_data, qr_bytes

    def test_actual_shell_publishes_default_current_apk_with_receipt_and_stable_qr(self):
        result, actions, calls, receipt, qr = self.fixture(use_default=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([a[0] for a in actions], ['prepare', 'publish', 'activate', 'cleanup'])
        self.assertEqual(actions[-1][1]['stage'], STAGE)
        self.assertEqual(receipt['version'], '0.6.1+8')
        self.assertIn('bansheng-0.6.1%2B8.apk', receipt['url'])
        self.assertIn('bansheng-latest.apk', receipt['download_url'])
        self.assertIn('█', result.stdout)
        self.assertIn(b'<svg', qr)
        sdk_calls = [call for call in calls if call[0] in ('aapt', 'apksigner')]
        self.assertEqual(len(sdk_calls), 2)
        self.assertEqual(receipt['certificate_sha256'], CERT)
        # Match the legacy encoder byte for byte: existing published QR is immutable.
        import qrcode
        from qrcode.image.svg import SvgPathFillImage
        import io
        expected = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, border=4)
        expected.add_data(receipt['download_url'])
        expected.make(fit=True)
        stream = io.BytesIO()
        expected.make_image(image_factory=SvgPathFillImage).save(stream)
        self.assertEqual(qr, stream.getvalue())

    def test_invalid_package_signing_filename_or_provenance_never_contacts_server(self):
        for option, reason in (('FOREIGN_PACKAGE', 'com.bansheng.prod'), ('DEBUG_APK', 'Debuggable'),
                               ('WRONG_CERT', 'certificate'), ('MULTIPLE_SIGNERS', 'certificate'),
                               ('MISSING_RECEIPT', 'receipt'), ('REPLACED_APK', 'changed'),
                               ('STALE_SOURCE', 'current Dart'), ('WRONG_FILENAME', 'filename')):
            with self.subTest(option=option):
                result, actions, _, receipt, _ = self.fixture(**{option: '1'})
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(actions, [])
                self.assertIsNone(receipt)
                self.assertIn(reason, result.stderr)

    def test_invalid_connection_settings_never_contact_server(self):
        for options in ({'APK_SSH_PORT': '70000'}, {'APK_SSH_HOST': 'user@host;command'}, {'APK_SSH_HOST': '-F@host'},
                        {'APK_PUBLIC_BASE_URL': 'http://example.invalid/apk'},
                        {'APK_PUBLIC_BASE_URL': 'https://user:secret@example.invalid/apk'},
                        {'APK_PUBLIC_BASE_URL': 'https://example.invalid/apk?token=secret'}):
            with self.subTest(options=options):
                result, actions, calls, receipt, _ = self.fixture(**options)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(actions, [])
                self.assertFalse(any(call[0] in ('ssh', 'scp', 'curl') for call in calls))
                self.assertIsNone(receipt)

    def test_failures_clean_own_staging_and_never_activate_unverified_release(self):
        for option in ('FAIL_UPLOAD', 'FAIL_QR_UPLOAD', 'FAIL_PUBLISH', 'FAIL_DOWNLOAD', 'WRONG_STATUS',
                       'WRONG_MIME', 'WRONG_CHECKSUM', 'CORRUPT_APK', 'CORRUPT_QR',
                       'CHANGE_SOURCE_ON_UPLOAD', 'CHANGE_SOURCE_ON_DOWNLOAD'):
            with self.subTest(option=option):
                result, actions, _, receipt, _ = self.fixture(**{option: '1'})
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                names = [a[0] for a in actions]
                self.assertEqual(names[0], 'prepare')
                self.assertEqual(names[-1], 'cleanup')
                self.assertNotIn('activate', names)
                self.assertIsNone(receipt)

    def test_activation_and_post_activation_failures_do_not_write_success_receipt(self):
        for option in ('FAIL_ACTIVATE', 'WRONG_LATEST', 'CORRUPT_STABLE'):
            with self.subTest(option=option):
                result, actions, _, receipt, _ = self.fixture(**{option: '1'})
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual([a[0] for a in actions], ['prepare', 'publish', 'activate', 'cleanup'])
                self.assertIsNone(receipt)

    def test_prepare_failure_and_invalid_stage_never_upload(self):
        for option in ('FAIL_PREPARE', 'INVALID_STAGE'):
            with self.subTest(option=option):
                result, actions, calls, receipt, _ = self.fixture(**{option: '1'})
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual([a[0] for a in actions], ['prepare'])
                self.assertFalse(any(call[0] == 'scp' for call in calls))
                self.assertIsNone(receipt)

    def test_cleanup_failure_preserves_original_upload_failure(self):
        result, actions, _, receipt, _ = self.fixture(FAIL_UPLOAD='1', FAIL_CLEANUP='1')
        self.assertEqual(result.returncode, 29, result.stdout + result.stderr)
        self.assertEqual([a[0] for a in actions], ['prepare', 'cleanup'])
        self.assertIn('cleanup failed', result.stderr)
        self.assertIsNone(receipt)

    def test_help_does_not_prepare_dependencies_or_publish(self):
        result = subprocess.run(['/bin/bash', str(SCRIPTS / 'publish-android-apk.sh'), '--help'],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0)
        self.assertIn('Usage:', result.stdout)


if __name__ == '__main__':
    unittest.main()
