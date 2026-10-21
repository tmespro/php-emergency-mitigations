#!/usr/bin/env bash
# =============================================================================
# php-emergency-mitigations: entry point
#
# Lists the available advisory modules and runs the one you name. Each module
# is self-contained and can also be run directly from advisories/<id>/.
#
# Usage:
#   bash mitigate.sh list
#   bash mitigate.sh <advisory-id> [options]       options are passed to the module
#   bash mitigate.sh <advisory-id> --help
#
# Examples:
#   bash mitigate.sh 2026-10-cve-2026-109618                 dry run
#   bash mitigate.sh 2026-10-cve-2026-109618 --apply
#   bash mitigate.sh 2026-10-cve-2026-109618 --revert --apply
#
# A RETIRED advisory can still be reverted, but no longer applied.
# https://github.com/tmespro/php-emergency-mitigations
# =============================================================================
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADV_DIR="$ROOT/advisories"

meta() {   # advisory dir, key  (plain key=value file, never sourced)
  sed -n "s/^$2=//p" "$1/META" 2>/dev/null | head -1
}

usage() {
  sed -n '3,/^# =====/{/^# =====/d;s/^# \{0,1\}//;p;}' "${BASH_SOURCE[0]}"
}

list() {
  local d found=0
  printf '%-28s %-9s %-11s %s\n' "ADVISORY" "STATUS" "PUBLISHED" "TITLE"
  for d in "$ADV_DIR"/*/; do
    d="${d%/}"
    if [[ ! -f "$d/META" || ! -f "$d/mitigate.sh" ]]; then continue; fi
    found=1
    printf '%-28s %-9s %-11s %s\n' "$(basename "$d")" "$(meta "$d" status)" "$(meta "$d" published)" "$(meta "$d" title)"
  done
  if (( ! found )); then echo "(no advisories found)"; fi
}

if [[ $# -eq 0 ]]; then usage; echo; list; exit 0; fi

case "$1" in
  list|--list) list; exit 0 ;;
  -h|--help|help) usage; exit 0 ;;
esac

ID="$1"; shift
if [[ ! "$ID" =~ ^[0-9]{4}-[0-9]{2}-[a-z0-9][a-z0-9-]*$ || ! -f "$ADV_DIR/$ID/mitigate.sh" || ! -f "$ADV_DIR/$ID/META" ]]; then
  echo "Unknown advisory: $ID"; echo; list; exit 2
fi

STATUS=$(meta "$ADV_DIR/$ID" status)
if [[ "$STATUS" == "RETIRED" ]]; then
  revert=0
  for a in "$@"; do if [[ "$a" == "--revert" ]]; then revert=1; fi; done
  if (( ! revert )); then
    echo "Advisory $ID is RETIRED: patched PHP builds are widely available, so it can no longer be applied."
    echo "Update PHP instead. To remove an earlier mitigation: bash mitigate.sh $ID --revert --apply"
    exit 2
  fi
fi

exec bash "$ADV_DIR/$ID/mitigate.sh" "$@"
