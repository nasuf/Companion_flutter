"""Regression: stale Dart snapshots must never pass APK verification."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('verify_android_aot', Path(__file__).parents[1] / 'verify_android_aot.py')
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def elf_fixture(code=b'current-code', data=b'current-data', debug=b''):
    names = b'\0.shstrtab\0.text\0.rodata\0.debug_info\0'
    payload = bytearray(64)
    payload[:6] = b'\x7fELF\x02\x01'
    records = [(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)]
    for name, value in [(b'.shstrtab', names), (b'.text', code), (b'.rodata', data), (b'.debug_info', debug)]:
        start = len(payload)
        payload.extend(value)
        records.append((names.index(name), 1, 0, 0, start, len(value), 0, 0, 1, 0))
    struct.pack_into('<Q', payload, 40, len(payload))
    struct.pack_into('<HHH', payload, 58, 64, len(records), 1)
    for record in records:
        payload.extend(struct.pack('<IIQQQQIIQQ', *record))
    return bytes(payload)


class AotTests(unittest.TestCase):
    def verify(self, source, packaged, extra=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            generated = root / 'jni/arm64-v8a/libapp.so'
            generated.parent.mkdir(parents=True)
            if source is not None:
                generated.write_bytes(source)
            apk = root / 'app.apk'
            with zipfile.ZipFile(apk, 'w') as archive:
                if packaged is not None:
                    archive.writestr('lib/arm64-v8a/libapp.so', packaged)
                if extra:
                    archive.writestr('lib/x86_64/libapp.so', packaged)
            return verifier.verify_apk(apk, root / 'jni')

    def test_stripping_debug_sections_is_allowed(self):
        self.assertEqual(self.verify(elf_fixture(debug=b'symbols'), elf_fixture()), ['arm64-v8a'])

    def test_stale_code_and_data_are_rejected(self):
        for old in [elf_fixture(code=b'old-code'), elf_fixture(data=b'old-data')]:
            with self.subTest(old=old), self.assertRaisesRegex(ValueError, 'stale'):
                self.verify(elf_fixture(), old)

    def test_missing_or_extra_architectures_are_rejected(self):
        for source, packaged, extra in [(None, elf_fixture(), False), (elf_fixture(), None, False), (elf_fixture(), elf_fixture(), True)]:
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                self.verify(source, packaged, extra)

    def test_invalid_and_truncated_elf_are_rejected(self):
        for bad in [b'bad', elf_fixture()[:70]]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                verifier.snapshot_sections(bad)


if __name__ == '__main__':
    unittest.main()
