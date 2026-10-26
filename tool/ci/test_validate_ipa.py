"""Structural checks use synthetic ZIPs, not an actual iOS build."""
import plistlib
import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

from validate_ipa import validate_ipa


class IpaValidationTests(unittest.TestCase):
    def make_ipa(self, path, *, platform="iPhoneOS", executable=True,
                 executable_mode=0o755, extra=None):
        metadata = {
            "CFBundleExecutable": "Runner",
            "CFBundleIdentifier": "com.aigym.aiGym",
            "CFBundlePackageType": "APPL",
            "CFBundleSupportedPlatforms": [platform],
            "MinimumOSVersion": "15.0",
        }
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("Payload/Runner.app/Info.plist", plistlib.dumps(metadata))
            if executable:
                info = zipfile.ZipInfo("Payload/Runner.app/Runner")
                info.create_system = 3
                info.external_attr = (stat.S_IFREG | executable_mode) << 16
                archive.writestr(info, b"synthetic executable for structural tests")
            if extra:
                archive.writestr(extra, b"unexpected")

    def test_valid_device_layout(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.ipa"
            self.make_ipa(path)
            self.assertEqual(validate_ipa(path)["CFBundleIdentifier"], "com.aigym.aiGym")

    def test_rejects_invalid_layouts(self):
        for options in (
            {"platform": "iPhoneSimulator"},
            {"executable": False},
            {"executable_mode": 0o644},
            {"extra": "Payload/../outside"},
            {"extra": "Payload/Other.app/Info.plist"},
        ):
            with self.subTest(options=options), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "app.ipa"
                self.make_ipa(path, **options)
                with self.assertRaises(ValueError):
                    validate_ipa(path)

    def test_rejects_missing_empty_and_non_zip(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.ipa"
            for content in (None, b"", b"not a ZIP"):
                if content is not None:
                    path.write_bytes(content)
                with self.assertRaises(ValueError):
                    validate_ipa(path)

    def test_rejects_zip_without_payload(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.ipa"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("Runner.app/Info.plist", b"wrong root")
            with self.assertRaises(ValueError):
                validate_ipa(path)


if __name__ == "__main__":
    unittest.main()
