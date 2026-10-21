"""Exercise the actual build script with isolated tool/IPA fixtures, without signing."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "build-testflight.sh"
TOOLS = r'''#!/usr/bin/env python3
import json, os, plistlib, sys, tempfile, zipfile
from pathlib import Path
tool = Path(sys.argv[0]).name
args = sys.argv[1:]
root = Path(os.environ['BUILD_TEST_FIXTURE_ROOT'])
if tool == 'git':
    sys.exit(128)  # The isolated fixture is deliberately outside a Git checkout.
if tool == 'pod':
    sys.exit(0)
if tool == 'mktemp':
    fd, path = tempfile.mkstemp(prefix=args[-1].replace('XXXXXX', ''), dir=root / 'temporary files')
    os.close(fd)
    print(path)
    sys.exit(0)
if tool == 'plutil':
    data = sys.stdin.buffer.read() if args[-1] == '-' else Path(args[-1]).read_bytes()
    print(plistlib.loads(data)[args[args.index('-extract') + 1]], end='')
    sys.exit(0)
if tool != 'flutter':
    raise RuntimeError('Unexpected tool: ' + tool)
with (root / 'flutter-calls.jsonl').open('a') as out:
    out.write(json.dumps(args) + '\n')
if args[:2] != ['build', 'ipa']:
    sys.exit(0)
for arg in args:
    if arg.startswith('--export-options-plist='):
        profile = plistlib.loads(Path(arg.split('=', 1)[1]).read_bytes())
        (root / 'export-options.json').write_text(json.dumps(profile))
if os.environ.get('BUILD_TEST_FAIL_BUILD') == '1':
    sys.exit(23)
config = dict(line.split(' = ', 1) for line in (root / 'ios/Flutter/FlavorOverride.xcconfig').read_text().splitlines())
ipa = root / 'build/ios/ipa/fixture.ipa'
ipa.parent.mkdir(parents=True)
with zipfile.ZipFile(ipa, 'w') as out:
    out.writestr('Payload/Runner.app/Info.plist', plistlib.dumps({
        'CFBundleIdentifier': config['APP_BUNDLE_ID'],
        'CFBundleDisplayName': '伴生' + config['APP_NAME_SUFFIX'],
    }))
    out.writestr('Payload/Runner.app/PlugIns/Share.appex/Info.plist', plistlib.dumps({
        'CFBundleIdentifier': config['APP_BUNDLE_ID'] + '.ShareExtension',
    }))
# The stub finishes in milliseconds; Bash 3.2's -nt uses whole seconds.
# Give the fixture an explicitly newer timestamp without slowing every test.
finished = max(p.stat().st_mtime for p in (root / 'temporary files').iterdir()) + 2
os.utime(ipa, (finished, finished))
'''


@unittest.skipUnless(Path("/bin/bash").exists() and shutil.which("unzip"), "Bash and unzip required")
class BuildTestflightTests(unittest.TestCase):
    def run_fixture(self, *, profiles=False, fail_build=False, flavor="dev", extra=()):
        with tempfile.TemporaryDirectory(prefix="testflight-script-") as directory:
            root = Path(directory) / "fixture project"
            for folder in ["scripts", "ios/Flutter", "tools", "temporary files"]:
                (root / folder).mkdir(parents=True)
            shutil.copy2(SCRIPT, root / "scripts/build-testflight.sh")
            for helper in ("fresh-build.sh", "flutter_build_guard.py"):
                shutil.copy2(SCRIPT.parent / helper, root / "scripts")
            version = "version: 0.1.0+7\n"
            (root / "pubspec.yaml").write_text(version)
            caller_plist = root / "caller-owned.plist"
            caller_plist.write_text("caller-owned content")
            for name in ["git", "pod", "mktemp", "plutil", "flutter"]:
                path = root / "tools" / name
                path.write_text(TOOLS)
                path.chmod(0o755)
            env = {k: v for k, v in os.environ.items() if not k.startswith("IOS_")}
            for key in ["BUILD_VERSION", "BUILD_NAME", "BUILD_NUMBER", "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"]:
                env.pop(key, None)
            env.update(
                PATH=str(root / "tools") + os.pathsep + os.environ["PATH"],
                BUILD_TEST_FIXTURE_ROOT=str(root), BUILD_TEST_FAIL_BUILD=str(int(fail_build)),
                FLAVOR=flavor, OPEN_TRANSPORTER="0", API_BASE_URL="https://example.invalid/api",
                IOS_APP_PROFILE_PATH=str(root / "missing.mobileprovision"),
                IOS_SHARE_EXTENSION_PROFILE_PATH=str(root / "missing-extension.mobileprovision"),
                export_options_plist=str(caller_plist),
            )
            if profiles:
                env.update(IOS_APP_PROFILE_NAME="Fixture App Store Profile",
                           IOS_SHARE_EXTENSION_PROFILE_NAME="Fixture Share Profile")
            result = subprocess.run(
                ["/bin/bash", str(root / "scripts/build-testflight.sh"), *extra],
                cwd=root, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=20,
            )
            self.assertFalse((root / "ios/Flutter/FlavorOverride.xcconfig").exists())
            self.assertEqual(list((root / "temporary files").iterdir()), [])
            self.assertEqual((root / "pubspec.yaml").read_text(), version)
            self.assertEqual(caller_plist.read_text(), "caller-owned content")
            calls_path = root / "flutter-calls.jsonl"
            calls = [json.loads(line) for line in calls_path.read_text().splitlines()] if calls_path.exists() else []
            exported_path = root / "export-options.json"
            exported = json.loads(exported_path.read_text()) if exported_path.exists() else None
            return result, calls, exported

    def test_automatic_signing_without_export_options_preserves_arguments(self):
        extra = ("--dart-define=GREETING=hello world", "--obfuscate")
        result, calls, exported = self.run_fixture(extra=extra)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls, [["clean"], ["pub", "get"], [
            "build", "ipa", "--release", "--build-name=0.1.0", "--build-number=7",
            "--dart-define=API_BASE_URL=https://example.invalid/api", *extra,
        ]])
        self.assertIsNone(exported)

    def test_manual_export_options_remain_one_argument_and_include_both_profiles(self):
        result, calls, exported = self.run_fixture(profiles=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        options = [arg for arg in calls[-1] if arg.startswith("--export-options-plist=")]
        self.assertEqual(len(options), 1)
        self.assertIn("temporary files", options[0])
        self.assertEqual(exported["provisioningProfiles"], {
            "com.bansheng.dev": "Fixture App Store Profile",
            "com.bansheng.dev.ShareExtension": "Fixture Share Profile",
        })

    def test_build_failure_preserves_exit_code_and_cleans_temporary_files(self):
        result, calls, _ = self.run_fixture(profiles=True, fail_build=True)
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertEqual(calls[-1][:2], ["build", "ipa"])

    def test_prod_still_requires_a_verified_local_profile(self):
        result, calls, _ = self.run_fixture(flavor="prod")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("Missing prod app provisioning profile", result.stderr)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
