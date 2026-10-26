"""Validate device IPA ZIP layout; this does not validate Apple signing."""
import argparse
import plistlib
import stat
import zipfile
from pathlib import Path, PurePosixPath


def validate_ipa(path):
    path = Path(path)
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"IPA missing or empty: {path}")
    try:
        with zipfile.ZipFile(path) as archive:
            if archive.testzip() is not None:
                raise ValueError("IPA ZIP CRC check failed")
            names = archive.namelist()
            if len(names) != len(set(names)):
                raise ValueError("Duplicate ZIP entries")
            for name in names:
                entry = PurePosixPath(name)
                if entry.is_absolute() or '..' in entry.parts or '\\' in name:
                    raise ValueError(f"Unsafe ZIP path: {name}")
            apps = {PurePosixPath(name).parts[1] for name in names
                    if len(PurePosixPath(name).parts) >= 2
                    and PurePosixPath(name).parts[0] == 'Payload'
                    and PurePosixPath(name).parts[1].endswith('.app')}
            if apps != {'Runner.app'}:
                raise ValueError("Expected exactly Payload/Runner.app")
            prefix = 'Payload/Runner.app/'
            metadata = plistlib.loads(archive.read(prefix + 'Info.plist'))
            if metadata.get('CFBundlePackageType') != 'APPL':
                raise ValueError("Not an iOS application bundle")
            if 'iPhoneOS' not in metadata.get('CFBundleSupportedPlatforms', []):
                raise ValueError("Expected a device build, not a simulator build")
            if not metadata.get('CFBundleIdentifier') or not metadata.get('MinimumOSVersion'):
                raise ValueError("Missing bundle identifier or minimum iOS version")
            executable = metadata.get('CFBundleExecutable', '')
            if not executable or '/' in executable or '\\' in executable or executable in {'.', '..'}:
                raise ValueError("Invalid bundle executable name")
            binary = archive.getinfo(prefix + executable)
            mode = binary.external_attr >> 16
            if binary.file_size == 0 or not stat.S_ISREG(mode) or not mode & 0o111:
                raise ValueError("Bundle executable missing content or Unix execute permissions")
            if not archive.read(prefix + executable):
                raise ValueError("Empty executable")
            return metadata
    except (zipfile.BadZipFile, KeyError, plistlib.InvalidFileException) as error:
        raise ValueError(f"Invalid IPA: {error}") from error


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    arguments = parser.parse_args()
    result = validate_ipa(arguments.ipa)
    print(f"IPA structure OK: {result['CFBundleIdentifier']}, iOS {result['MinimumOSVersion']}+")
    print('Unsigned artifact: Sideloadly must sign it before installation.')
