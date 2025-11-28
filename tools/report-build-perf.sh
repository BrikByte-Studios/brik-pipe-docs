#!/usr/bin/env bash
#
# BrikByteOS Pipelines — Build Perf Reporter
#
# Purpose:
#   - Fetch recent workflow runs for a given example service from GitHub Actions.
#   - Compute "cold" vs "warm" build durations (first vs second successful run).
#   - Append a structured record into a JSON metrics file.
#
# Usage:
#   tools/report-build-perf.sh <service_id> <workflow_file> [branch] [repo]
#
#   Examples:
#     # Node API (default branch: main, default repo: brik-pipe-examples)
#     tools/report-build-perf.sh node-api .github/workflows/node-api-use-kaniko.yml
#
#     # Python service, explicit branch
#     tools/report-build-perf.sh python-api .github/workflows/python-api-use-kaniko.yml main
#
#     # Explicit repo override (if you mirror examples elsewhere)
#     tools/report-build-perf.sh node-api .github/workflows/node-api-use-kaniko.yml main BrikByte-Studios/brik-pipe-examples
#
# Requirements:
#   - `jq` installed (for JSON parsing).
#   - `curl` installed.
#   - `GITHUB_TOKEN` environment variable set with:
#       - `repo` read access for the target repo.
#       - (Optional) `read:actions` depending on org policy.
#
# Notes:
#   - This script does NOT modify build-perf-dashboard.md directly.
#     Instead it records machine-friendly data in a JSON file:
#       containers/build-perf-metrics.json
#     You can then manually update the markdown dashboard using these metrics.
#
set -euo pipefail

# -------------------------------
# Configuration defaults
# -------------------------------

# Default GitHub repo to query for workflow runs (owner/repo)
DEFAULT_REPO="BrikByte-Studios/brik-pipe-examples"

# Default branch for CI runs
DEFAULT_BRANCH="main"

# Where to store metrics relative to the repo where you keep docs
# You can adjust this to match your layout (e.g. "./build-perf-metrics.json")
METRICS_FILE="containers/build-perf-metrics.json"

# -------------------------------
# Helper: print usage
# -------------------------------
usage() {
  cat <<EOF
Usage:
  $0 <service_id> <workflow_file> [branch] [repo]

Arguments:
  service_id    Logical name of the service (e.g. node-api, python-api, java-api).
  workflow_file Path to workflow file in the target repo
                (e.g. .github/workflows/node-api-use-kaniko.yml).
  branch        (Optional) Branch name, default: ${DEFAULT_BRANCH}
  repo          (Optional) owner/repo, default: ${DEFAULT_REPO}

Environment:
  GITHUB_TOKEN  Required. PAT or fine-grained token with access to Actions.

Example:
  $0 node-api .github/workflows/node-api-use-kaniko.yml
EOF
}

# -------------------------------
# Validate inputs
# -------------------------------

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

SERVICE_ID="$1"
WORKFLOW_FILE="$2"
BRANCH="${3:-$DEFAULT_BRANCH}"
REPO="${4:-$DEFAULT_REPO}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN is not set. Please export GITHUB_TOKEN and retry." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed." >&2
  exit 1
fi

# -------------------------------
# Helper: compute duration in seconds between two ISO timestamps
# -------------------------------
# Uses GNU date. On macOS, you may need 'gdate' from coreutils.
#
iso_diff_seconds() {
  local start_ts="$1"
  local end_ts="$2"

  # Detect gdate vs date (Linux vs macOS)
  if command -v gdate >/dev/null 2>&1; then
    date_cmd="gdate"
  else
    date_cmd="date"
  fi

  local start_epoch end_epoch
  start_epoch="$($date_cmd -d "$start_ts" +%s)"
  end_epoch="$($date_cmd -d "$end_ts" +%s)"

  echo $(( end_epoch - start_epoch ))
}

# -------------------------------
# Step 1: Resolve workflow ID from file name
# -------------------------------
echo "🔎 Resolving workflow ID for '${WORKFLOW_FILE}' in repo '${REPO}'..."

WORKFLOWS_JSON="$(
  curl -sS \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}/actions/workflows"
)"

# Check for top-level API error (e.g. Bad credentials, Not Found)
API_MESSAGE="$(echo "$WORKFLOWS_JSON" | jq -r '.message // empty')"
if [[ -n "$API_MESSAGE" ]]; then
  echo "❌ GitHub API error when listing workflows:"
  echo "    message: $API_MESSAGE"
  echo "    repo:    $REPO"
  echo "    hint:    Check GITHUB_TOKEN scopes and repository name."
  exit 1
fi

# Ensure .workflows is present and an array
HAS_WORKFLOWS="$(
  echo "$WORKFLOWS_JSON" | jq -r 'has("workflows")'
)"

if [[ "$HAS_WORKFLOWS" != "true" ]]; then
  echo "❌ Unexpected response from GitHub when listing workflows for ${REPO}."
  echo "   Raw response:"
  echo "$WORKFLOWS_JSON"
  exit 1
fi

WORKFLOW_ID="$(
  echo "$WORKFLOWS_JSON" | jq -r \
    --arg wf "$WORKFLOW_FILE" \
    '.workflows[] | select(.path == $wf) | .id' || true
)"

if [[ -z "$WORKFLOW_ID" || "$WORKFLOW_ID" == "null" ]]; then
  echo "❌ Could not find workflow with path '${WORKFLOW_FILE}' in repo '${REPO}'."
  echo "   Known workflow paths in this repo:"
  echo "$WORKFLOWS_JSON" | jq -r '.workflows[].path'
  exit 1
fi

echo "✅ Workflow ID for '${WORKFLOW_FILE}' is: ${WORKFLOW_ID}"


# -------------------------------
# Step 2: Fetch recent successful runs for that workflow
# -------------------------------
echo "📥 Fetching recent successful runs for workflow ${WORKFLOW_ID} on branch '${BRANCH}'..."

RUNS_JSON="$(
  curl -sS \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}/actions/workflows/${WORKFLOW_ID}/runs?branch=${BRANCH}&status=success&per_page=5"
)"

RUN_COUNT="$(
  echo "$RUNS_JSON" | jq '.workflow_runs | length'
)"

if [[ "$RUN_COUNT" -lt 2 ]]; then
  echo "ERROR: Need at least 2 successful runs to compute cold vs warm builds. Found: ${RUN_COUNT}" >&2
  exit 1
fi

# Take the two most recent successful runs
# GitHub returns runs sorted by created_at desc by default.
FIRST_RUN="$(echo "$RUNS_JSON" | jq '.workflow_runs[0]')"
SECOND_RUN="$(echo "$RUNS_JSON" | jq '.workflow_runs[1]')"

FIRST_ID="$(echo "$FIRST_RUN" | jq -r '.id')"
SECOND_ID="$(echo "$SECOND_RUN" | jq -r '.id')"

FIRST_CREATED="$(echo "$FIRST_RUN" | jq -r '.run_started_at // .created_at')"
FIRST_UPDATED="$(echo "$FIRST_RUN" | jq -r '.updated_at')"

SECOND_CREATED="$(echo "$SECOND_RUN" | jq -r '.run_started_at // .created_at')"
SECOND_UPDATED="$(echo "$SECOND_RUN" | jq -r '.updated_at')"

echo "📊 Using runs:"
echo "  - Cold  (most recent):   ID=${FIRST_ID}, started=${FIRST_CREATED}, finished=${FIRST_UPDATED}"
echo "  - Warm  (previous run):  ID=${SECOND_ID}, started=${SECOND_CREATED}, finished=${SECOND_UPDATED}"

# -------------------------------
# Step 3: Compute durations in seconds
# -------------------------------
COLD_SECONDS="$(iso_diff_seconds "$FIRST_CREATED" "$FIRST_UPDATED")"
WARM_SECONDS="$(iso_diff_seconds "$SECOND_CREATED" "$SECOND_UPDATED")"

echo "⏱  Duration (seconds): cold=${COLD_SECONDS}, warm=${WARM_SECONDS}"

# -------------------------------
# Step 4: Build metrics entry
# -------------------------------
TIMESTAMP_NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

NEW_ENTRY="$(jq -n \
  --arg service_id "$SERVICE_ID" \
  --arg repo "$REPO" \
  --arg workflow_file "$WORKFLOW_FILE" \
  --arg branch "$BRANCH" \
  --arg cold_run_id "$FIRST_ID" \
  --arg warm_run_id "$SECOND_ID" \
  --arg cold_started "$FIRST_CREATED" \
  --arg cold_finished "$FIRST_UPDATED" \
  --arg warm_started "$SECOND_CREATED" \
  --arg warm_finished "$SECOND_UPDATED" \
  --arg measured_at "$TIMESTAMP_NOW" \
  --argjson cold_seconds "$COLD_SECONDS" \
  --argjson warm_seconds "$WARM_SECONDS" \
  '{
    service_id: $service_id,
    repo: $repo,
    workflow_file: $workflow_file,
    branch: $branch,
    cold_run: {
      id: $cold_run_id,
      started_at: $cold_started,
      finished_at: $cold_finished,
      duration_seconds: $cold_seconds
    },
    warm_run: {
      id: $warm_run_id,
      started_at: $warm_started,
      finished_at: $warm_finished,
      duration_seconds: $warm_seconds
    },
    delta_seconds: ($cold_seconds - $warm_seconds),
    measured_at: $measured_at
  }'
)"

echo "🧾 New metrics entry:"
echo "$NEW_ENTRY" | jq '.'

# -------------------------------
# Step 5: Append to metrics JSON file
# -------------------------------
# If file does not exist, create a new JSON array.
# If file exists, append to array.
# -------------------------------
mkdir -p "$(dirname "$METRICS_FILE")"

if [[ ! -f "$METRICS_FILE" ]]; then
  echo "📂 Metrics file '${METRICS_FILE}' not found. Creating a new one."
  echo "[$NEW_ENTRY]" > "$METRICS_FILE"
else
  echo "📂 Metrics file '${METRICS_FILE}' exists. Appending new entry."
  tmp_file="$(mktemp)"

  jq \
    --argjson new_entry "$NEW_ENTRY" \
    '. + [$new_entry]' \
    "$METRICS_FILE" > "$tmp_file"

  mv "$tmp_file" "$METRICS_FILE"
fi

echo "✅ Metrics updated in: ${METRICS_FILE}"
echo "   You can now use these values to update build-perf-dashboard.md."
