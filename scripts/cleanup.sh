#!/usr/bin/env bash
# Removes ONLY resources labelled app.kubernetes.io/part-of=healthcare-devsecops-pbl3.
# Usage: cleanup.sh [--delete-namespace] [--images]   (--yes to skip the prompt)
. "$(dirname "$0")/lib.sh"; need kubectl
delns=false; imgs=false; yes=false
for a in "$@"; do case "$a" in --delete-namespace) delns=true;; --images) imgs=true;; --yes) yes=true;; *) die "unknown option $a";; esac; done
if [ "$yes" != true ]; then read -r -p "Delete project resources in namespace '$K8S_NAMESPACE' ($DEPLOY_ENV)? [y/N] " r; [[ "$r" =~ ^[Yy]$ ]] || exit 0; fi
k -n "$K8S_NAMESPACE" delete deployment,service,configmap,networkpolicy,secret -l "$PART_OF" --ignore-not-found
if [ "$delns" = true ] && k get ns "$K8S_NAMESPACE" -o jsonpath='{.metadata.labels}' 2>/dev/null | grep -q healthcare-devsecops-pbl3; then
  k delete namespace "$K8S_NAMESPACE"
else [ "$delns" = true ] && log "namespace not labelled as created by this project - left in place"; fi
if [ "$imgs" = true ] && command -v docker >/dev/null 2>&1; then
  for i in "$(cicd_image)" "$(blue_image)" "$(green_image)"; do docker rmi "$i" 2>/dev/null || true
    command -v minikube >/dev/null 2>&1 && minikube -p "$MINIKUBE_PROFILE" image rm "$i" 2>/dev/null || true; done
fi
rm -rf "$ROOT/kubernetes/.render"; log "cleanup done"
