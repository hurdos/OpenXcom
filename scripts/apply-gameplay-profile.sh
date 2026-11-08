#!/usr/bin/env bash
#
# Apply one of the macOS gameplay balance profiles from
# docs/gameplay/profiles to the current user's options.cfg.
#
set -euo pipefail

cd "$(dirname "$0")/.."

exec ./scripts/apply-graphics-profile.sh --dir docs/gameplay/profiles "$@"
