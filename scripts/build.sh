#!/usr/bin/env bash
# Builds a ready-to-open Roblox place file from this repository.
# Requires Rojo: https://rojo.space/docs/v7/getting-started/installation/
#   ./scripts/build.sh                          -> BrainrotObby.rbxlx in the repo root
#   ./scripts/build.sh build/BrainrotObby.rbxl  -> refresh the committed snapshots
#   ./scripts/build.sh build/BrainrotObby.rbxlx
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-BrainrotObby.rbxlx}"
mkdir -p "$(dirname "$OUT")"
rojo build default.project.json -o "$OUT"
echo "Built $OUT  ->  open it in Roblox Studio, then File > Publish to Roblox."
