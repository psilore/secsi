#!/usr/bin/env bash

set -e

OWNER=""
TEAM_SLUG=""

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

format_error() {
  printf '%sERROR: %s%s\n' "${FMT_BOLD}${FMT_RED}" "$*" "$FMT_RESET" >&2
}

setup_colors(){
FMT_RED=$(printf '\033[31m')
FMT_BLUE=$(printf '\033[34m')
FMT_RESET=$(printf '\033[0m')
}


get_repo_names() {
  local OWNER="$1"
  local TEAM_SLUG="$2"
  local URL

  if [ -z "$TEAM_SLUG" ]; then
    URL="orgs/$OWNER/repos"
  else
    URL="orgs/$OWNER/teams/$TEAM_SLUG/repos"
  fi

  fetch_and_save_repo_names "$URL"
}

fetch_and_save_repo_names() {
  local URL="$1"
  local ACTIVE_REPOS
  local REPO_NAMES

  ACTIVE_REPOS=$(gh api "$URL" 2>&1)

  if [ $? -ne 0 ]; then
    format_error "Failed to fetch data from GitHub API:"
    echo "$ACTIVE_REPOS"
    exit 1
  fi

  REPO_NAMES=$(echo "$ACTIVE_REPOS" | jq -r '.[].name' 2>&1)

  if [ $? -ne 0 ]; then
    format_error "Failed to parse JSON with jq:"
    echo "$REPO_NAMES"
    exit 1
  fi

  echo "$REPO_NAMES" > "$REPO_LIST"
}

get_alerts() {
  if [ "$(tail -c 1 "$REPO_LIST")" ]; then
    echo "$REPO_LIST does not end with a newline character! Exiting..."
    exit 1
  fi

  REPOS=$(cat "$REPO_LIST")

  ALERTS_DATA="alerts.json"
  echo "[]" > "$ALERTS_DATA"

  for REPO in $REPOS; do

    REPO_DETAILS=$(gh api "/repos/$OWNER/$REPO" --jq '{archived: .archived}')
    IS_ARCHIVED=$(echo "$REPO_DETAILS" | jq -r '.archived')

    if [ "$IS_ARCHIVED" = "true" ]; then
      echo "Skipping archived repository: $REPO"
      continue
    fi

    URL="/repos/$OWNER/$REPO/dependabot/alerts"
    ACTIVE_ALERTS=$(gh api "$URL" --jq "[.[] | select(.state == \"open\") | {repository: \"$REPO\", number: .number, state: .state, security_advisory: .security_advisory.summary, severity: .security_advisory.severity, cve: (.security_advisory.identifiers[] | select(.type == \"CVE\") | .value)}]")

    
    if [ -n "$ACTIVE_ALERTS" ]; then
      jq -s '.[0] + .[1]' "$ALERTS_DATA" <(echo "$ACTIVE_ALERTS") > tmp.json && mv tmp.json "$ALERTS_DATA"
    fi
  done
  
  if grep -q '"severity": "critical"' "$ALERTS_DATA"; then
    rm -f critical.json
    jq '[.[] | select(.severity == "critical")]' "$ALERTS_DATA" > "$GIT_ROOT_DIR/critical.json"
  fi
}

setup() {
  setup_colors

  command_exists git || {
    format_error "git is not installed"
    exit 1
  }

  command_exists tail || {
    format_error "tail is not installed"
    exit 1
  }

  GIT_ROOT_DIR=$(git rev-parse --show-toplevel)
  REPO_LIST="$GIT_ROOT_DIR/active_repos.txt"
  ALERTS_DATA="$GIT_ROOT_DIR/alerts.json"
  LOGS_DIR="tmp/logs"
  LOG_FILE="$LOGS_DIR/status.log"

  mkdir -p "$LOGS_DIR"
  touch "$LOG_FILE"
  rm -f "$REPO_LIST"
  rm -f "$ALERTS_DATA"

  if [ -z "$TEAM_SLUG" ]; then
    printf '%s\n' "Fetching dependabot alerts organisation: $OWNER repositories"
    get_repo_names "$OWNER"
    get_alerts
  else
    printf '%s\n' "Fetching dependabot alerts for team: $TEAM_SLUG repositories"
    get_repo_names "$OWNER" "$TEAM_SLUG"
    get_alerts
  fi

}

usage() {
  printf '%s\n' "Usage: $(basename "$0") [OPTIONS]"
  printf '\n'
  printf '%s\n' "Options:"
  printf '\n'
  printf '%s\n' "  -h               Show this help message"
  printf '\n'
  printf '%s\n' "  -o [Required]    Owner in GitHub"
  printf '\n'
  printf '%s\n' "  -t               Team name in GitHub, if no team name is provided,"
  printf '%s\n' "                   all dependabot alerts in the organizations repositories will be checked"
  printf '\n'
}

main() {
  while getopts "ho:t:" opt; do
    case $opt in
      h)
        usage
        exit 0
        ;;
      o)
        OWNER="$OPTARG"
        ;;
      t)
        TEAM_SLUG="$OPTARG"
        ;;
      \?)
        usage
        exit 1
        ;;
    esac
  done
  # Check required options
  if [[ -z $OWNER ]]; then
    format_error "Option [OWNER] is required"
    usage
    exit 1
  fi

  setup
  exit 0
}


main "$@"
