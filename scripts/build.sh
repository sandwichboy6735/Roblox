#!/usr/bin/env bash
# Builds a ready-to-open Roblox place file from this repository.
# Requires Rojo: https://rojo.space/docs/v7/getting-started/installation/
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-HatchLegends.rbxlx}"
rojo build default.project.json -o "$OUT"
echo "Built $OUT  ->  open it in Roblox Studio, then File > Publish to Roblox."
