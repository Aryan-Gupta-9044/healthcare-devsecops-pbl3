#!/usr/bin/env bash
# Shared helpers. Every value is environment-driven; defaults suit local Minikube.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEPLOY_ENV="${DEPLOY_ENV:-local}"            # local | aws
export K8S_NAMESPACE="${K8S_NAMESPACE:-healthcare}"
export K8S_CONTEXT="${K8S_CONTEXT:-}"
export DOCKER_IMAGE="${DOCKER_IMAGE:-healthcare-app}"        # aws: <dockerhub-user>/healthcare-app
export DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-1.0.0}"         # VLE 7 tag/version
export BLUE_VERSION="${BLUE_VERSION:-1.0.0}"
export GREEN_VERSION="${GREEN_VERSION:-2.0.0}"
export SERVICE_NAME="${SERVICE_NAME:-healthcare-service}"
export MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
PART_OF="app.kubernetes.io/part-of=healthcare-devsecops-pbl3"
case "$DEPLOY_ENV" in local|aws) ;; *) echo "DEPLOY_ENV must be local or aws" >&2; exit 2;; esac

KUBECTL=(kubectl); [ -n "$K8S_CONTEXT" ] && KUBECTL+=(--context "$K8S_CONTEXT")
k() { "${KUBECTL[@]}" "$@"; }
log() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found in PATH"; }
json_get() { python3 -c 'import sys,json; print(json.loads(sys.argv[1]).get(sys.argv[2],""))' "$1" "$2"; }

cicd_image()  { echo "$DOCKER_IMAGE:$DOCKER_IMAGE_TAG"; }
blue_image()  { echo "$DOCKER_IMAGE:${BLUE_VERSION}-blue"; }
green_image() { echo "$DOCKER_IMAGE:${GREEN_VERSION}-green"; }

# Render a kustomize overlay with the image/namespace for this run (no tracked file is modified).
render() { # common|vle7|blue|green
  local t="$1" dir="$ROOT/kubernetes/.render/$1-$DEPLOY_ENV" img="" name
  mkdir -p "$dir"
  case "$t" in
    vle7)  img="healthcare-app|$DOCKER_IMAGE|$DOCKER_IMAGE_TAG";;
    blue)  img="healthcare-app-blue|$DOCKER_IMAGE|${BLUE_VERSION}-blue";;
    green) img="healthcare-app-green|$DOCKER_IMAGE|${GREEN_VERSION}-green";;
  esac
  { echo "apiVersion: kustomize.config.k8s.io/v1beta1"; echo "kind: Kustomization"
    echo "namespace: $K8S_NAMESPACE"; echo "resources:"; echo "  - ../../overlays/$DEPLOY_ENV/$t"
    if [ -n "$img" ]; then IFS='|' read -r name repo tag <<<"$img"
      echo "images:"; echo "  - name: $name"; echo "    newName: $repo"; echo "    newTag: \"$tag\""; fi
  } > "$dir/kustomization.yaml"
  k kustomize "$dir"
}

ensure_namespace() {
  if k get namespace "$K8S_NAMESPACE" >/dev/null 2>&1; then log "namespace $K8S_NAMESPACE exists - left untouched"
  else log "creating namespace $K8S_NAMESPACE"
    k create namespace "$K8S_NAMESPACE"
    k label namespace "$K8S_NAMESPACE" "$PART_OF" pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/warn=restricted
  fi
}

ensure_pull_secret() { # aws only; needs DOCKERHUB_USERNAME + DOCKERHUB_TOKEN
  [ "$DEPLOY_ENV" = aws ] || return 0
  if [ -z "${DOCKERHUB_USERNAME:-}" ] || [ -z "${DOCKERHUB_TOKEN:-}" ]; then
    log "no registry credentials supplied - skipping pull secret (fine for public images)"; return 0; fi
  local tmp; tmp="$(mktemp)"; chmod 600 "$tmp"
  python3 - "$tmp" <<'PY'
import base64, json, os, sys
u, t = os.environ["DOCKERHUB_USERNAME"], os.environ["DOCKERHUB_TOKEN"]
auth = base64.b64encode(f"{u}:{t}".encode()).decode()
json.dump({"auths": {"https://index.docker.io/v1/": {"username": u, "password": t, "auth": auth}}}, open(sys.argv[1], "w"))
PY
  k -n "$K8S_NAMESPACE" create secret generic regcred --type=kubernetes.io/dockerconfigjson \
    --from-file=.dockerconfigjson="$tmp" --dry-run=client -o yaml | k apply -f -
  k -n "$K8S_NAMESPACE" label secret regcred "$PART_OF" --overwrite >/dev/null
  rm -f "$tmp"
}

push_image() { # aws: registry push; credentials via env (never stored)
  local img="$1"
  if [ -n "${DOCKERHUB_USERNAME:-}" ] && [ -n "${DOCKERHUB_TOKEN:-}" ]; then
    printf '%s' "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin >/dev/null
  else log "no DOCKERHUB_* set - relying on an existing 'docker login'"; fi
  docker push "$img"
}

load_image() { # local: get the image into the cluster; aws: push to registry
  local img="$1" ctx
  if [ "$DEPLOY_ENV" = aws ]; then push_image "$img"; return; fi
  ctx="${K8S_CONTEXT:-$(kubectl config current-context 2>/dev/null || true)}"
  if command -v minikube >/dev/null 2>&1 && { [ "$ctx" = "$MINIKUBE_PROFILE" ] || [[ "$ctx" == minikube* ]]; }; then
    log "minikube image load $img"; minikube -p "$MINIKUBE_PROFILE" image load "$img"
  elif [[ "$ctx" == kind-* ]] && command -v kind >/dev/null 2>&1; then
    kind load docker-image "$img" --name "${ctx#kind-}"
  else log "context '$ctx': assuming the cluster shares the local Docker daemon (Docker Desktop)"; fi
}

# GET a path through kubectl port-forward (works on any cluster, no NodePort/IP needed).
pf_get() { # target(e.g. svc/healthcare-service) remote-port path
  local port=$((20000 + RANDOM % 20000)) pid body="" i
  k -n "$K8S_NAMESPACE" port-forward "$1" "$port:$2" >/dev/null 2>&1 & pid=$!
  for i in $(seq 1 20); do
    if body="$(curl -fsS --max-time 3 "http://127.0.0.1:$port$3" 2>/dev/null)"; then break; fi; body=""; sleep 1
  done
  kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
  [ -n "$body" ] || return 1
  printf '%s' "$body"
}
