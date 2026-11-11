#!/usr/bin/env bash
# One-shot local bootstrap (safe to re-run). Usage: setup.sh [--start-minikube]
. "$(dirname "$0")/lib.sh"
start=false; [ "${1:-}" = "--start-minikube" ] && start=true
ok=true
for t in docker kubectl minikube python3 curl; do
  if command -v "$t" >/dev/null 2>&1; then echo "  [ok] $t"; else echo "  [missing] $t"; ok=false; fi; done
$ok || die "install the missing tools first (see docs/JENKINS_SETUP.md)"
docker info >/dev/null 2>&1 || die "Docker daemon not reachable"
if ! minikube -p "$MINIKUBE_PROFILE" status >/dev/null 2>&1; then
  if [ "$start" = true ]; then minikube start -p "$MINIKUBE_PROFILE" --cpus=2 --memory=2048 --cni=calico
  else die "Minikube is not running. Start it (minikube start --cpus=2 --memory=2048 --cni=calico) or re-run with --start-minikube"; fi
fi
if [ -n "${JENKINS_URL:-}" ]; then
  curl -fsS -o /dev/null --max-time 5 "$JENKINS_URL/login" && echo "  [ok] Jenkins reachable at $JENKINS_URL" || echo "  [warn] Jenkins not reachable at $JENKINS_URL"
else echo "  [info] JENKINS_URL not set - skipping Jenkins check"; fi
k cluster-info >/dev/null || die "kubectl cannot reach the cluster"
"$ROOT/scripts/build.sh" vle7
"$ROOT/scripts/deploy.sh" vle7
"$ROOT/scripts/verify.sh" vle7-http
log "Setup complete. Open it with:  minikube service healthcare-cicd-service -n $K8S_NAMESPACE"
