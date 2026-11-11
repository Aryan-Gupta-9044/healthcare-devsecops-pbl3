#!/usr/bin/env bash
# Usage: rollback.sh [color]   default: blue. The old deployment is never deleted, so this is instant.
. "$(dirname "$0")/lib.sh"; need kubectl
to="${1:-blue}"
cur="$(k -n "$K8S_NAMESPACE" get svc "$SERVICE_NAME" -o jsonpath='{.spec.selector.version}')"
if [ "$cur" = "$to" ]; then log "already serving $to - nothing to roll back"; "$ROOT/scripts/verify.sh" traffic "$to"; exit 0; fi
log "ROLLBACK: $cur -> $to"
"$ROOT/scripts/blue-green-switch.sh" "$to"
