#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_root"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'Packaging requires macOS (Codemagic); use validate_ipa.py for ZIP checks on Windows.' >&2
  exit 1
fi

# Only accept the physical-device output; never package an iphonesimulator app.
app_path="$(find build/ios/iphoneos -maxdepth 1 -type d -name Runner.app -print -quit)"
if [[ -z "$app_path" || ! -f "$app_path/Info.plist" || ! -s "$app_path/Runner" ]]; then
  echo 'Missing build/ios/iphoneos/Runner.app or bundle executable.' >&2
  exit 1
fi
/usr/bin/plutil -lint "$app_path/Info.plist"
# -verify_arch consumes every following argument as an architecture name.
/usr/bin/lipo "$app_path/Runner" -verify_arch arm64
if [[ ! -x "$app_path/Runner" ]]; then
  echo 'Runner executable has lost its execute permissions.' >&2
  exit 1
fi

output_dir="$project_root/build/ios/ipa"
mkdir -p "$output_dir"
ipa_path="$output_dir/FlutterApp-unsigned.ipa"
# Remove a stale archive before zip; otherwise zip can retain obsolete entries.
rm -f "$ipa_path"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/aigym-ipa.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
mkdir -p "$staging_dir/Payload"
# ditto preserves bundle contents, symlinks and Unix permissions.
/usr/bin/ditto "$app_path" "$staging_dir/Payload/Runner.app"
(
  cd "$staging_dir"
  /usr/bin/zip -qry "$ipa_path" Payload
)
test -s "$ipa_path"
/usr/bin/unzip -tq "$ipa_path"
python3 tool/ci/validate_ipa.py "$ipa_path"
/usr/bin/shasum -a 256 "$ipa_path" > "$ipa_path.sha256"
echo "Unsigned IPA prepared: $ipa_path"
