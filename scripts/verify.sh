#!/usr/bin/env bash
# Usage: verify.sh image <ref> | vle7-k8s | vle7-http | blue | green | traffic <blue|green>
. "$(dirname "$0")/lib.sh"
ns="$K8S_NAMESPACE"
check_deploy() { # deployment color version
  need kubectl
  k -n "$ns" rollout status "deployment/$1" --timeout=120s
  k -n "$ns" get deployments,pods,services -l "$PART_OF" -o wide
  local h s; h="$(pf_get "deploy/$1" 8080 /health)" || die "$1 /health unreachable"
  [ "$(json_get "$h" status)" = healthy ] || die "$1 unhealthy: $h"
  s="$(pf_get "deploy/$1" 8080 /api/status)" || die "$1 /api/status unreachable"
  echo "$s"
  [ "$(json_get "$s" color)" = "$2" ]   || die "expected color $2, got $(json_get "$s" color)"
  [ "$(json_get "$s" version)" = "$3" ] || die "expected version $3, got $(json_get "$s" version)"
  log "OK: $1 healthy, color=$2 version=$3"
}
case "${1:-}" in
  image)
    need docker; ref="${2:?image ref required}"
    docker image inspect "$ref" >/dev/null 2>&1 || die "image $ref not found"
    user="$(docker image inspect -f '{{.Config.User}}' "$ref")"
    [ -n "$user" ] && [ "$user" != 0 ] && [ "$user" != root ] || die "image runs as root (USER='$user')"
    log "image OK: $ref  user=$user  size=$(docker image inspect -f '{{.Size}}' "$ref") bytes";;
  vle7-k8s)
    need kubectl; k -n "$ns" rollout status deployment/healthcare-cicd --timeout=120s
    k -n "$ns" get deployments; k -n "$ns" get pods -o wide; k -n "$ns" get services
    ready="$(k -n "$ns" get deploy healthcare-cicd -o jsonpath='{.status.readyReplicas}')"
    [ "${ready:-0}" -ge 1 ] || die "no ready replicas";;
  vle7-http)
    need kubectl
    h="$(pf_get svc/healthcare-cicd-service 80 /health)" || die "/health failed"; echo "$h"
    [ "$(json_get "$h" status)" = healthy ] || die "unhealthy"
    s="$(pf_get svc/healthcare-cicd-service 80 /api/status)" || die "/api/status failed"; echo "$s"
    [ "$(json_get "$s" version)" = "$DOCKER_IMAGE_TAG" ] || die "version mismatch"
    pf_get svc/healthcare-cicd-service 80 / | grep -q "Patient records" || die "dashboard HTML check failed"
    log "OK: dashboard, /health and /api/status respond";;
  blue)  check_deploy healthcare-blue blue "$BLUE_VERSION";;
  green) check_deploy healthcare-green green "$GREEN_VERSION";;
  traffic)
    want="${2:?color required}"; need kubectl
    sel="$(k -n "$ns" get svc "$SERVICE_NAME" -o jsonpath='{.spec.selector.version}')"
    [ "$sel" = "$want" ] || die "service selector is '$sel', expected '$want'"
    s="$(pf_get "svc/$SERVICE_NAME" 80 /api/status)" || die "service unreachable"; echo "$s"
    [ "$(json_get "$s" color)" = "$want" ] || die "traffic reached '$(json_get "$s" color)', expected '$want'"
    log "OK: $SERVICE_NAME routes to $want (selector=$sel)";;
  *) die "usage: verify.sh image <ref>|vle7-k8s|vle7-http|blue|green|traffic <color>";;
esac
