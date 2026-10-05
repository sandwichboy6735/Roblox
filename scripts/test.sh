#!/usr/bin/env bash
# Runs the offline Luau tests for shared logic and Config data.
# Needs the `luau` CLI on PATH: https://github.com/luau-lang/luau/releases
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"
BUNDLE="$(mktemp "${TMPDIR:-/tmp}/hatchlegends-tests.XXXXXX")"
trap 'rm -f "$BUNDLE"' EXIT
{
	cat tests/stubs.luau
	echo 'local Config = (function()'
	cat src/Shared/Config.lua
	echo 'end)()'
	echo 'local Util = (function()'
	cat src/Shared/Util.lua
	echo 'end)()'
	echo 'local Codes = (function()'
	cat src/Server/Codes.lua
	echo 'end)()'
	cat tests/run.luau
} > "$BUNDLE"
"$LUAU" "$BUNDLE"
