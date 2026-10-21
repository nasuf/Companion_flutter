#!/usr/bin/env python3
"""Reject APKs containing stale Dart AOT, allowing Android's debug stripping."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import struct
import zipfile


def snapshot_sections(data: bytes) -> dict[str, str]:
    if len(data) < 64 or data[:4] != b'\x7fELF' or data[4] not in (1, 2) or data[5] not in (1, 2):
        raise ValueError('Invalid ELF runtime')
    endian = '<' if data[5] == 1 else '>'
    wide = data[4] == 2
    offset = struct.unpack_from(endian + ('Q' if wide else 'I'), data, 40 if wide else 32)[0]
    size, count, names_index = struct.unpack_from(endian + 'HHH', data, 58 if wide else 46)
    fmt = endian + ('IIQQQQIIQQ' if wide else 'IIIIIIIIII')
    if size < struct.calcsize(fmt) or count == 0 or names_index >= count or offset + size * count > len(data):
        raise ValueError('Invalid ELF section table')
    sections = [struct.unpack_from(fmt, data, offset + i * size) for i in range(count)]
    names_section = sections[names_index]
    names = data[names_section[4]:names_section[4] + names_section[5]]
    result = {}
    for section in sections:
        name = names[section[0]:].split(b'\0', 1)[0]
        if name in (b'.text', b'.rodata'):
            start, length = section[4:6]
            if not length or start + length > len(data):
                raise ValueError('Invalid Dart snapshot section')
            result[name.decode()] = hashlib.sha256(data[start:start + length]).hexdigest()
    if set(result) != {'.text', '.rodata'}:
        raise ValueError('Dart snapshot sections missing')
    return result


def verify_apk(apk: Path, generated_jni: Path) -> list[str]:
    expected = {p.parent.name: p for p in generated_jni.glob('*/libapp.so')}
    if not expected:
        raise ValueError('Current Flutter AOT output is missing')
    with zipfile.ZipFile(apk) as archive:
        actual = {name.split('/')[1]: name for name in archive.namelist()
                  if name.startswith('lib/') and name.endswith('/libapp.so') and name.count('/') == 2}
        if set(actual) != set(expected):
            raise ValueError(f'APK AOT architectures differ: expected {sorted(expected)}, got {sorted(actual)}')
        for abi, source in expected.items():
            if snapshot_sections(source.read_bytes()) != snapshot_sections(archive.read(actual[abi])):
                raise ValueError(f'APK contains stale Flutter AOT for {abi}')
    return sorted(expected)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('generated_jni', type=Path)
    args = parser.parse_args()
    try:
        abis = verify_apk(args.apk, args.generated_jni)
    except (ValueError, OSError, zipfile.BadZipFile, struct.error) as exc:
        parser.exit(1, f'Android AOT verification failed: {exc}\n')
    print('Verified current Flutter AOT in APK: ' + ', '.join(abis))


if __name__ == '__main__':
    main()
