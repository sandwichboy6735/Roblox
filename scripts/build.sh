#!/usr/bin/env bash
# Builds a ready-to-open Roblox place file from this repository.
# Requires Rojo: https://rojo.space/docs/v7/getting-started/installation/
#   ./scripts/build.sh                 -> HatchLegends.rbxlx in the repo root
#   ./scripts/build.sh build/HatchLegends.rbxl    -> refresh the committed snapshots
#   ./scripts/build.sh build/HatchLegends.rbxlx
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-HatchLegends.rbxlx}"
mkdir -p "$(dirname "$OUT")"
rojo build default.project.json -o "$OUT"
echo "Built $OUT  ->  open it in Roblox Studio, then File > Publish to Roblox."
