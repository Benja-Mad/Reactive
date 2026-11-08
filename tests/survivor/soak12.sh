#!/bin/bash
# soak12.sh OUT [extra soak flags]: the 12 soak seeds (support and showcase 1-6), three at a time.
# One line per run: mode seed time credited kills errors all-damage weapon-damage.
cd "$(dirname "$0")/../.."
out=$1; shift; extra="$*"; : > "$out"
run() {
  local log; log=$(mktemp)
  timeout 900 godot --headless --path . --audio-driver Dummy res://tests/survivor/soak.tscn -- seed=$2 $1 $extra > "$log" 2>&1
  local t; t=$(grep -o '"time":[0-9.]*' "$log" | tail -1 | cut -d: -f2)
  echo "$1 $2 $t $(grep -o '"credited":[0-9]*' "$log" | tail -1) $(grep -o '"kills":[0-9]*' "$log" | tail -1) e=$(grep -c 'SCRIPT ERROR' "$log") $(grep -o '"all":[0-9.]*' "$log" | tail -1) $(grep -o '"weapon":[0-9.]*' "$log" | tail -1)" >> "$out"
  rm -f "$log"
}
for mode in support showcase; do for seed in 1 2 3 4 5 6; do
  run $mode $seed &
  while [ "$(jobs -r | wc -l)" -ge 3 ]; do sleep 2; done
done; done
wait; sort -k1,1r -k2,2n "$out" -o "$out"
awk '{s[$1]+=$3; n[$1]++} END {for (m in s) printf "%s mean %.1f s\n", m, s[m]/n[m]}' "$out"
