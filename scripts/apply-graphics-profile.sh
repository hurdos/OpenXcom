#!/usr/bin/env bash
#
# Apply an OpenXcom profile (graphics or gameplay) to the current user's
# options.cfg. The graphics profiles are the default; --dir selects another
# profile directory (see scripts/apply-gameplay-profile.sh).
#
set -euo pipefail

cd "$(dirname "$0")/.."

PROFILE_DIR="${PROFILE_DIR:-docs/macos-graphics/profiles}"
OPTIONS_FILE="${OPENXCOM_OPTIONS:-$HOME/Library/Application Support/OpenXcom/options.cfg}"

usage() {
	cat <<'EOF'
Usage: scripts/apply-graphics-profile.sh [options] PROFILE

Options:
  --dir DIR       profile directory (default: docs/macos-graphics/profiles)
  --list          list available profiles
  --show PROFILE  print a profile without applying it
  --launch        launch OpenXcom after applying the profile
  -h, --help      show this help

Examples:
  ./scripts/apply-graphics-profile.sh --list
  ./scripts/apply-graphics-profile.sh balanced-fullscreen
  ./scripts/apply-graphics-profile.sh sharp-windowed --launch

The game must be closed before applying a profile. The script changes only
the keys listed in the profile and creates a timestamped backup of options.cfg.
EOF
}

list_profiles() {
	echo "Available profiles:"
	find "$PROFILE_DIR" -maxdepth 1 -type f -name '*.yml' -print | sort | while IFS= read -r file; do
		local name description
		name="$(basename "$file" .yml)"
		description="$(sed -n 's/^# description:[[:space:]]*//p' "$file" | head -n 1)"
		printf '  %-28s %s\n' "$name" "$description"
	done
}

PROFILE=""
LAUNCH=0

while [ $# -gt 0 ]; do
	case "$1" in
		--dir)
			if [ $# -lt 2 ]; then
				echo "ERROR: --dir requires a directory" >&2
				exit 2
			fi
			PROFILE_DIR="$2"
			shift 2
			;;
		--dir=*)
			PROFILE_DIR="${1#*=}"
			shift
			;;
		--list)
			list_profiles
			exit 0
			;;
		--show)
			if [ $# -lt 2 ]; then
				echo "ERROR: --show requires a profile name" >&2
				exit 2
			fi
			profile_name="${2%.yml}"
			profile_file="$PROFILE_DIR/$profile_name.yml"
			if [ ! -f "$profile_file" ]; then
				echo "ERROR: unknown profile: $profile_name" >&2
				list_profiles >&2
				exit 1
			fi
			cat "$profile_file"
			exit 0
			;;
		--launch)
			LAUNCH=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		-*)
			echo "ERROR: unknown option: $1" >&2
			usage >&2
			exit 2
			;;
		*)
			PROFILE="${1%.yml}"
			shift
			;;
	esac
done

if [ -z "$PROFILE" ]; then
	usage
	exit 2
fi

PROFILE_FILE="$PROFILE_DIR/$PROFILE.yml"
if [ ! -f "$PROFILE_FILE" ]; then
	echo "ERROR: unknown profile: $PROFILE" >&2
	list_profiles >&2
	exit 1
fi

if [ ! -f "$OPTIONS_FILE" ]; then
	echo "ERROR: options file not found: $OPTIONS_FILE" >&2
	echo "Launch OpenXcom once, quit it, and run this script again." >&2
	exit 1
fi

if pgrep -f 'OpenXcom.app/Contents/MacOS/openxcom' >/dev/null 2>&1; then
	echo "ERROR: OpenXcom is running. Quit it before applying a profile." >&2
	exit 1
fi

python3 - "$OPTIONS_FILE" "$PROFILE_FILE" <<'PY'
import datetime
import os
import re
import shutil
import sys

options_path, profile_path = sys.argv[1], sys.argv[2]

items = []
for line in open(profile_path, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    if ":" not in line:
        continue
    key, value = line.split(":", 1)
    key, value = key.strip(), value.strip()
    if not re.fullmatch(r"[A-Za-z0-9_]+", key):
        continue
    items.append((key, value))

settings = dict(items)
lines = open(options_path, encoding="utf-8").read().splitlines()
out = []
found = set()

for line in lines:
    match = re.match(r"^  ([A-Za-z0-9_]+):(.*)$", line)
    if match and match.group(1) in settings:
        key = match.group(1)
        out.append(f"  {key}: {settings[key]}")
        found.add(key)
    else:
        out.append(line)

missing = [(key, value) for key, value in items if key not in found]
if missing:
    options_index = next((i for i, line in enumerate(out) if line.rstrip() == "options:"), None)
    if options_index is None:
        print("ERROR: 'options:' block not found in options.cfg", file=sys.stderr)
        sys.exit(1)
    end = len(out)
    for index in range(options_index + 1, len(out)):
        if out[index] and not out[index].startswith(" "):
            end = index
            break
    for offset, (key, value) in enumerate(missing):
        out.insert(end + offset, f"  {key}: {value}")

stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
backup_path = f"{options_path}.bak-{stamp}"
suffix = 1
while os.path.exists(backup_path):
    backup_path = f"{options_path}.bak-{stamp}-{suffix}"
    suffix += 1
shutil.copy2(options_path, backup_path)
open(options_path, "w", encoding="utf-8").write("\n".join(out) + "\n")

print(f"Applied {len(found) + len(missing)} settings from {os.path.basename(profile_path)}")
print(f"Backup: {backup_path}")
PY

echo "Profile '$PROFILE' applied to:"
echo "  $OPTIONS_FILE"

if [ "$LAUNCH" -eq 1 ]; then
	APP="/Applications/OpenXcom.app"
	if [ ! -d "$APP" ]; then
		APP="dist/OpenXcom.app"
	fi
	if [ ! -d "$APP" ]; then
		echo "ERROR: OpenXcom.app not found in /Applications or dist/" >&2
		exit 1
	fi
	echo "Launching: $APP"
	open "$APP"
fi
