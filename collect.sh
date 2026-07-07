#!/bin/bash
# resource-kuma collector — runs every 30s via systemd timer
# Writes a rolling 24h window to $DATA_FILE as a JSON array

DATA_DIR="${RESOURCE_KUMA_DATA_DIR:-/var/lib/resource-kuma}"
DATA_FILE="$DATA_DIR/data.json"
STATE_FILE="$DATA_DIR/.cpu_state"
MAX_POINTS=2880  # 24h at 30s intervals

mkdir -p "$DATA_DIR"

# --- CPU ---
read_cpu() {
  awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8}' /proc/stat
}

cpu_pct=0
if [ -f "$STATE_FILE" ]; then
  prev=$(cat "$STATE_FILE")
  curr=$(read_cpu)

  prev_idle=$(echo $prev | awk '{print $4}')
  prev_total=$(echo $prev | awk '{t=0; for(i=1;i<=NF;i++) t+=$i; print t}')
  curr_idle=$(echo $curr | awk '{print $4}')
  curr_total=$(echo $curr | awk '{t=0; for(i=1;i<=NF;i++) t+=$i; print t}')

  diff_idle=$((curr_idle - prev_idle))
  diff_total=$((curr_total - prev_total))

  if [ "$diff_total" -gt 0 ]; then
    cpu_pct=$(awk "BEGIN {printf \"%.1f\", (1 - $diff_idle / $diff_total) * 100}")
  fi
fi
read_cpu > "$STATE_FILE"

# --- Memory ---
mem_total=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
mem_avail=$(awk '/^MemAvailable/ {print $2}' /proc/meminfo)
mem_used=$(( (mem_total - mem_avail) / 1024 ))
mem_total_mb=$(( mem_total / 1024 ))

# --- Containers ---
containers_json=""
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  while IFS=$'\t' read -r name mem_usage mem_limit; do
    # parse "123.4MiB / 512MiB" style strings
    parse_mb() {
      echo "$1" | awk '{
        val=$1; unit=$2
        if (unit ~ /GiB/) val = val * 1024
        else if (unit ~ /kB|KiB/) val = val / 1024
        printf "%.0f", val
      }'
    }
    used_mb=$(echo "$mem_usage" | awk '{split($0,a," / "); print a[1]}' | parse_mb)
    limit_mb=$(echo "$mem_usage" | awk '{split($0,a," / "); print a[2]}' | parse_mb)
    [ -n "$containers_json" ] && containers_json+=","
    containers_json+="{\"name\":\"$name\",\"used\":$used_mb,\"limit\":$limit_mb}"
  done < <(docker stats --no-stream --format $'{{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}' 2>/dev/null)
fi

ts=$(date +%s)
new_point="{\"ts\":$ts,\"cpu\":$cpu_pct,\"mem_used\":$mem_used,\"mem_total\":$mem_total_mb,\"containers\":[$containers_json]}"

# Rolling window — append and trim to MAX_POINTS
if [ -f "$DATA_FILE" ] && [ -s "$DATA_FILE" ]; then
  python3 -c "
import json, sys
with open('$DATA_FILE') as f:
  data = json.load(f)
data.append(json.loads(sys.argv[1]))
data = data[-$MAX_POINTS:]
with open('$DATA_FILE', 'w') as f:
  json.dump(data, f, separators=(',',':'))
" "$new_point" 2>/dev/null || echo "[$new_point]" > "$DATA_FILE"
else
  echo "[$new_point]" > "$DATA_FILE"
fi
