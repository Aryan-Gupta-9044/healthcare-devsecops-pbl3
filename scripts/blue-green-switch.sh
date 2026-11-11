#!/usr/bin/env bash
# Usage: blue-green-switch.sh green|blue   - real selector patch on the Service (no simulation).
. "$(dirname "$0")/lib.sh"; need kubectl
to="${1:-green}"; [[ "$to" == blue || "$to" == green ]] || die "usage: $0 green|blue"
ns="$K8S_NAMESPACE"
from="$(k -n "$ns" get svc "$SERVICE_NAME" -o jsonpath='{.spec.selector.version}')"
ready="$(k -n "$ns" get deploy "healthcare-$to" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
[ "${ready:-0}" -ge 1 ] || die "healthcare-$to has no ready replicas - refusing to switch"
log "selector before: version=$from"
k -n "$ns" patch svc "$SERVICE_NAME" --type merge \
  -p "{\"metadata\":{\"annotations\":{\"healthcare/previous-color\":\"$from\"}},\"spec\":{\"selector\":{\"app\":\"healthcare\",\"version\":\"$to\"}}}"
k -n "$ns" get svc "$SERVICE_NAME" -o jsonpath='selector after: {.spec.selector}{"\n"}'
"$ROOT/scripts/verify.sh" traffic "$to"
