#!/bin/bash
# Measures how much CPU and memory each screen saver uses, running in its optimized test app, and
# warns when one goes over budget. Also samples GPU utilization, which macOS only reports for the
# whole system, so close other busy apps for a meaningful number.
#
#   Tools/perf-check.sh                    every saver in Savers/
#   Tools/perf-check.sh Pipes FlowerBox    just these
#
# Settings, as environment variables:
#   CPU_LIMIT=20        budget in percent of one CPU core, averaged over the measurement
#   GPU_LIMIT=          optional budget in percent of the GPU (system-wide)
#   WARMUP_SECONDS=10   skipped before measuring, so one-off setup isn't counted
#   MEASURE_SECONDS=30  how long to measure each saver
#   HARNESS_ARGS=       extra flags for the test apps, e.g. --battery to measure the reduced
#                       frame rate the savers switch to on battery or in Low Power Mode
#
# Each test app opens a 1280x800 window, which has to stay visible while it's measured, and uses the
# Options saved in that test app. Exits with status 1 if any saver is over budget.
set -euo pipefail
cd "$(dirname "$0")/.."

CPU_LIMIT=${CPU_LIMIT:-20}
GPU_LIMIT=${GPU_LIMIT:-}
WARMUP_SECONDS=${WARMUP_SECONDS:-10}
MEASURE_SECONDS=${MEASURE_SECONDS:-30}
HARNESS_ARGS=${HARNESS_ARGS:-}

savers=("$@")
if [ ${#savers[@]} -eq 0 ]; then
    for directory in Savers/*/; do
        savers+=("$(basename "$directory")")
    done
fi

# Average system-wide GPU utilization (percent) over the given number of seconds.
sample_gpu() {
    local total=0 count=0 value
    for ((i = 0; i < $1; i++)); do
        value=$(ioreg -r -d 1 -w 0 -c IOAccelerator | grep -o '"Device Utilization %"=[0-9]*' | head -1 | cut -d= -f2)
        total=$((total + ${value:-0}))
        count=$((count + 1))
        sleep 1
    done
    echo $((total / count))
}

# Prints 1 if $1 > $2 (both may be decimals), else 0.
exceeds() {
    awk -v value="$1" -v limit="$2" 'BEGIN { print (value > limit) ? 1 : 0 }'
}

log=$(mktemp)
idle_gpu=$(sample_gpu 3)
rows=()
over_budget=()

for saver in "${savers[@]}"; do
    echo "Building $saver…"
    if ! make harness SAVER="$saver" >"$log" 2>&1; then
        cat "$log"
        exit 2
    fi

    echo "Measuring $saver for ${MEASURE_SECONDS}s after ${WARMUP_SECONDS}s of warm-up…"
    app="build/Build/Products/Release/Retro${saver}Harness.app/Contents/MacOS/Retro${saver}Harness"
    # HARNESS_ARGS is split into separate flags on purpose.
    # shellcheck disable=SC2086
    "$app" --measure "$MEASURE_SECONDS" --warmup "$WARMUP_SECONDS" $HARNESS_ARGS >"$log" 2>/dev/null &
    pid=$!
    sleep "$WARMUP_SECONDS"
    gpu=$(sample_gpu "$MEASURE_SECONDS")
    wait "$pid" || true

    line=$(grep '^MEASURED' "$log" || true)
    if [ -z "$line" ]; then
        echo "  $saver didn't report a measurement."
        over_budget+=("$saver")
        continue
    fi
    cpu=$(sed -E 's/.*cpu_average=([0-9.]+).*/\1/' <<<"$line")
    peak=$(sed -E 's/.*cpu_peak=([0-9.]+).*/\1/' <<<"$line")
    memory=$(sed -E 's/.*memory_mb=([0-9]+).*/\1/' <<<"$line")

    verdict="ok"
    if [ "$(exceeds "$cpu" "$CPU_LIMIT")" = 1 ]; then
        verdict="CPU over ${CPU_LIMIT}%"
    fi
    if [ -n "$GPU_LIMIT" ] && [ "$(exceeds "$gpu" "$GPU_LIMIT")" = 1 ]; then
        if [ "$verdict" = "ok" ]; then verdict="GPU over ${GPU_LIMIT}%"; else verdict="$verdict, GPU over ${GPU_LIMIT}%"; fi
    fi
    if [ "$verdict" != "ok" ]; then
        over_budget+=("$saver")
    fi
    rows+=("$(printf '%-12s %8s%% %8s%% %8s MB %9s%%   %s' "$saver" "$cpu" "$peak" "$memory" "$gpu" "$verdict")")
done
rm -f "$log"

echo
printf '%-12s %9s %9s %11s %10s   %s\n' "Saver" "CPU avg" "CPU peak" "Memory" "GPU" ""
# (The ${array[@]+...} form keeps macOS's bash 3.2 happy when the array is empty.)
for row in ${rows[@]+"${rows[@]}"}; do
    echo "$row"
done
echo
echo "CPU is percent of one core; GPU is system-wide (${idle_gpu}% before the test apps ran).${HARNESS_ARGS:+ Test app flags: $HARNESS_ARGS}"

if [ ${#over_budget[@]} -gt 0 ]; then
    echo "⚠️  Over budget: ${over_budget[*]+${over_budget[*]}}"
    exit 1
fi
echo "All within budget (CPU limit ${CPU_LIMIT}%${GPU_LIMIT:+, GPU limit ${GPU_LIMIT}%})."
