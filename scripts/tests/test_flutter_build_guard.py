"""Run every Flutter entry point against stale-output and failed-build fixtures."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from test_android_aot import elf_fixture

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import flutter_build_guard as guard


TOOLS = r'''#!/usr/bin/env python3
import json, os, plistlib, shutil, sys, zipfile
from pathlib import Path
root = Path(os.environ['FIXTURE_ROOT'])
tool, args = Path(sys.argv[0]).name, sys.argv[1:]
with (root / 'calls.jsonl').open('a') as stream:
    stream.write(json.dumps([tool, *args]) + '\n')
if tool == 'git': sys.exit(128)
if tool == 'adb':
    if args == ['devices']: print('List of devices attached\nfixture-device\tdevice')
    elif 'install' in args: (root / 'installed.txt').write_text(args[-1])
    elif 'pm' in args: print('package:/data/app/fixture/base.apk')
    elif 'exec-out' in args:
        sys.stdout.buffer.write(b'old device APK' if os.environ.get('INSTALLED_OLD') == '1' else Path((root / 'installed.txt').read_text()).read_bytes())
    sys.exit(0)
if tool == 'flutter':
    if args == ['clean']:
        if os.environ.get('BAD_CLEAN') != '1':
            shutil.rmtree(root / 'build', ignore_errors=True)
            shutil.rmtree(root / '.dart_tool', ignore_errors=True)
    elif args[:1] == ['build']:
        if os.environ.get('FAIL_BUILD') == '1': sys.exit(23)
        if os.environ.get('NO_OUTPUT') == '1': sys.exit(0)
        if args[1] == 'apk':
            mode = next(mode for mode in ['release', 'profile', 'debug'] if '--'+mode in args)
            flavor = args[args.index('--flavor') + 1]
            apk = root / f'build/app/outputs/flutter-apk/app-{flavor}-{mode}.apk'
            apk.parent.mkdir(parents=True, exist_ok=True)
            runtime = (root / 'fixture.so').read_bytes()
            with zipfile.ZipFile(apk, 'w') as z:
                z.writestr('lib/arm64-v8a/libapp.so', runtime.replace(b'current-code', b'old-old-code') if os.environ.get('STALE_AOT') == '1' else runtime)
            jni = root / f'build/app/intermediates/flutter/{flavor}{mode.title()}/jniLibs/arm64-v8a/libapp.so'
            jni.parent.mkdir(parents=True, exist_ok=True)
            jni.write_bytes(runtime)
        elif args[1] == 'ios':
            platform = 'iphonesimulator' if '--simulator' in args else 'iphoneos'
            app = root / f'build/ios/{platform}/Runner.app'
            app.mkdir(parents=True)
            (app / 'Runner').write_text('current native code')
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.bansheng.prod'}))
        if os.environ.get('CHANGE_SOURCE') == '1':
            (root / 'lib/main.dart').write_text('changed while building')
    sys.exit(0)
if tool in ['pod', 'xcrun', 'xattr']: sys.exit(0)
raise RuntimeError('Unexpected tool: ' + tool)
'''


class RunScriptTests(unittest.TestCase):
    def fixture(self, script='run-android-device.sh', *, mode='release', extra=(), **options):
        with tempfile.TemporaryDirectory(prefix='flutter-script-') as directory:
            root = Path(directory) / 'project with spaces'
            for name in ('scripts', 'tools', 'lib', 'ios/Flutter', 'build/stale', '.dart_tool/flutter_build'):
                (root / name).mkdir(parents=True)
            for path in SCRIPTS.glob('*.sh'):
                shutil.copy2(path, root / 'scripts')
            for name in ('flutter_build_guard.py', 'verify_android_aot.py'):
                shutil.copy2(SCRIPTS / name, root / 'scripts')
            (root / 'pubspec.yaml').write_text('version: 1.0.0+1\n')
            (root / 'lib/main.dart').write_text('current source')
            (root / 'fixture.so').write_bytes(elf_fixture())
            for name in ('flutter', 'adb', 'git', 'pod', 'xcrun', 'xattr'):
                path = root / 'tools' / name
                path.write_text(TOOLS)
                path.chmod(0o755)
            env = {k: v for k, v in os.environ.items() if not k.startswith(('COMPANION_BUILD_', 'IOS_', 'FLUTTER_'))}
            env.update(PATH=str(root / 'tools') + os.pathsep + os.environ['PATH'], FIXTURE_ROOT=str(root),
                       FLAVOR='prod', FLUTTER_RUN_MODE=mode, PHYSICAL_DEVICE_ID='iphone',
                       IPAD_DEVICE_ID='ipad', ANDROID_DEVICE_ID='android', **options)
            result = subprocess.run(['/bin/bash', str(root / 'scripts' / script), *extra],
                                    cwd=directory, env=env, stdin=subprocess.DEVNULL,
                                    capture_output=True, text=True, timeout=25)
            calls_file = root / 'calls.jsonl'
            calls = [json.loads(line) for line in calls_file.read_text().splitlines()] if calls_file.exists() else []
            return result, calls

    def test_android_build_is_verified_before_running_exact_binary(self):
        for mode in ('release', 'profile'):
            with self.subTest(mode=mode):
                result, calls = self.fixture(mode=mode, extra=('--dart-define=GREETING=hello world',))
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                flutter = [call[1:] for call in calls if call[0] == 'flutter']
                self.assertEqual(flutter[:2], [['clean'], ['pub', 'get']])
                self.assertEqual(flutter[2][:2], ['build', 'apk'])
                self.assertIn('--dart-define=GREETING=hello world', flutter[2])
                self.assertTrue(any(arg.endswith(f'app-prod-{mode}.apk') and arg.startswith('--use-application-binary=') for arg in flutter[3]))

    def test_runtime_options_go_to_launch_and_compiler_options_to_both(self):
        result, calls = self.fixture(extra=('--route', '/chat', '--no-resident', '--dart-define=KEY=hello world'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        flutter = [call[1:] for call in calls if call[0] == 'flutter']
        self.assertNotIn('--route', flutter[2])
        self.assertIn('--route', flutter[3])
        self.assertIn('--no-resident', flutter[3])
        self.assertIn('--dart-define=KEY=hello world', flutter[2])
        self.assertIn('--dart-define=KEY=hello world', flutter[3])

    def test_no_install_or_launch_after_failed_stale_missing_or_mutating_build(self):
        for option in ('FAIL_BUILD', 'STALE_AOT', 'NO_OUTPUT', 'CHANGE_SOURCE', 'BAD_CLEAN', 'INSTALLED_OLD'):
            with self.subTest(option=option):
                result, calls = self.fixture(**{option: '1'})
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse(any(call[:2] == ['flutter', 'run'] or call[0] == 'xcrun' for call in calls))

    def test_all_run_scripts_start_fresh_and_debug_keeps_hot_reload(self):
        for script in ('run-android-device.sh', 'run-iphone-device.sh', 'run-ipad-device.sh',
                       'run-iphone-simulator.sh', 'run-ipad-simulator.sh'):
            with self.subTest(script=script):
                result, calls = self.fixture(script, mode='debug')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                flutter = [call[1:] for call in calls if call[0] == 'flutter']
                self.assertEqual(flutter[:2], [['clean'], ['pub', 'get']])
                self.assertEqual(flutter[2][:1], ['build'])
                self.assertTrue(any(arg.startswith('--use-application-binary=') for arg in flutter[-1]))
                self.assertNotIn('--no-hot', flutter[-1])

    def test_ios_devices_never_install_old_app_on_failure(self):
        for script in ('run-iphone-device.sh', 'run-ipad-device.sh'):
            for option in ('FAIL_BUILD', 'NO_OUTPUT', 'CHANGE_SOURCE'):
                with self.subTest(script=script, option=option):
                    result, calls = self.fixture(script, **{option: '1'})
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(any(call[0] == 'xcrun' for call in calls))

    def test_every_entry_point_rejects_build_bypass(self):
        for script in ('run-android-device.sh', 'run-iphone-device.sh', 'run-ipad-device.sh',
                       'run-iphone-simulator.sh', 'run-ipad-simulator.sh',
                       'build-testflight.sh', 'build-android-apk.sh', 'publish-android-apk.sh'):
            for option in ('--no-build', '--build=false', '--use-application-binary=old.apk', '--config-only'):
                with self.subTest(script=script, option=option):
                    result, calls = self.fixture(script, extra=(option,))
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('not allowed', result.stderr)
                    self.assertFalse(any(call[0] == 'flutter' for call in calls))


class ReceiptTests(unittest.TestCase):
    def test_changed_dart_assets_dependencies_and_artifact_block_delivery(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'lib').mkdir()
            (root / 'assets').mkdir()
            (root / 'lib/main.dart').write_text('source')
            (root / 'assets/gift.png').write_bytes(b'asset')
            (root / 'pubspec.lock').write_text('dependencies')
            apk = root / 'app.apk'
            apk.write_bytes(b'current build')
            with patch.object(guard, 'ROOT', root), patch.object(guard, 'source_digest', side_effect=lambda: original(root)):
                for path in (root / 'lib/main.dart', root / 'assets/gift.png', root / 'pubspec.lock', apk):
                    with self.subTest(path=path):
                        guard.seal(apk, original(root))
                        before = path.read_bytes()
                        path.write_bytes(before + b'changed')
                        with self.assertRaises(ValueError):
                            guard.verify(apk)
                        path.write_bytes(before)
                guard.seal(apk, original(root))
                guard.verify(apk)
                guard.receipt_path(apk).write_text('[]')
                with self.assertRaisesRegex(ValueError, 'receipt'):
                    guard.verify(apk)
                guard.receipt_path(apk).unlink()
                with self.assertRaisesRegex(ValueError, 'receipt'):
                    guard.verify(apk)

    def test_concurrent_scripts_are_rejected_without_waiting(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(guard, 'ROOT', Path(directory)):
            key = hashlib.sha256(str(guard.ROOT).encode()).hexdigest()
            with (Path(tempfile.gettempdir()) / f'companion-flutter-build-{key}.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with self.assertRaisesRegex(ValueError, 'Another Flutter'):
                    guard.locked('/does/not/matter.sh', [])


original = guard.source_digest

if __name__ == '__main__':
    unittest.main()
