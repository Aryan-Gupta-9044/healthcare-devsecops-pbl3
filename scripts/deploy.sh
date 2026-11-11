#!/usr/bin/env bash
# Usage: deploy.sh vle7|blue|green   (idempotent; same logic for DEPLOY_ENV=local and aws)
. "$(dirname "$0")/lib.sh"; need kubectl
target="${1:-vle7}"
ensure_namespace
ensure_pull_secret
render common | k apply -f -
case "$target" in
  vle7)
    render vle7 | k apply -f -
    [ "${FORCE_RESTART:-false}" = true ] && k -n "$K8S_NAMESPACE" rollout restart deployment/healthcare-cicd
    k -n "$K8S_NAMESPACE" rollout status deployment/healthcare-cicd --timeout=180s;;
  blue)
    # Keep the live selector if the service already exists (re-running must not undo a switch).
    prev="$(k -n "$K8S_NAMESPACE" get svc "$SERVICE_NAME" -o jsonpath='{.spec.selector.version}' 2>/dev/null || true)"
    render blue | k apply -f -
    if [ -n "$prev" ] && [ "$prev" != blue ]; then
      log "service already routes to '$prev' - preserving it"
      k -n "$K8S_NAMESPACE" patch svc "$SERVICE_NAME" --type merge -p "{\"spec\":{\"selector\":{\"version\":\"$prev\"}}}"
    fi
    [ "${FORCE_RESTART:-false}" = true ] && k -n "$K8S_NAMESPACE" rollout restart deployment/healthcare-blue
    k -n "$K8S_NAMESPACE" rollout status deployment/healthcare-blue --timeout=180s;;
  green)
    render green | k apply -f -
    [ "${FORCE_RESTART:-false}" = true ] && k -n "$K8S_NAMESPACE" rollout restart deployment/healthcare-green
    k -n "$K8S_NAMESPACE" rollout status deployment/healthcare-green --timeout=180s;;
  *) die "usage: deploy.sh vle7|blue|green";;
esac
log "deployed $target to namespace $K8S_NAMESPACE ($DEPLOY_ENV)"
