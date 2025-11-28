#!/usr/bin/env bash
#
# BrikByteOS Pipelines — Build Perf Table Printer
#
# Purpose:
#   Read containers/build-perf-metrics.json and print a Markdown table
#   summarizing the *latest* cold vs warm durations per service_id.
#
# Usage:
#   ./tools/print-build-perf-table.sh
#
# Requirements:
#   - jq installed
#   - containers/build-perf-metrics.json exists and is valid JSON
#

set -euo pipefail

METRICS_FILE="containers/build-perf-metrics.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed." >&2
  exit 1
fi

if [[ ! -f "$METRICS_FILE" ]]; then
  echo "ERROR: Metrics file not found: $METRICS_FILE" >&2
  echo "Hint: run tools/report-build-perf.sh first to generate metrics." >&2
  exit 1
fi

# jq program:
#  - group by service_id
#  - sort each group by measured_at
#  - take last (most recent) entry for each service
#  - output a compact array of summary rows
SUMMARY_JSON="$(
  jq '
    group_by(.service_id)
    | map(
        sort_by(.measured_at) | last
      )
  ' "$METRICS_FILE"
)"

# If the resulting array is empty, bail out with a helpful message
ROW_COUNT="$(echo "$SUMMARY_JSON" | jq 'length')"
if [[ "$ROW_COUNT" -eq 0 ]]; then
  echo "No metrics entries found in $METRICS_FILE." >&2
  exit 1
fi

# Print Markdown header
cat <<EOF
| Service | Cold (s) | Warm (s) | Delta (s) | Cold Run ID | Warm Run ID | Measured At |
|--------|----------|----------|-----------|-------------|-------------|-------------|
EOF

# Print rows
echo "$SUMMARY_JSON" | jq -r '
  .[] |
  [
    .service_id,
    .cold_run.duration_seconds,
    .warm_run.duration_seconds,
    .delta_seconds,
    .cold_run.id,
    .warm_run.id,
    .measured_at
  ]
  | @tsv
' | while IFS=$'\t' read -r service cold warm delta cold_id warm_id measured_at; do
  echo "| ${service} | ${cold} | ${warm} | ${delta} | ${cold_id} | ${warm_id} | ${measured_at} |"
done
