#!/usr/bin/env python3
"""Security policy-as-code validation for the Dockerfile and Kubernetes base manifests."""
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
failures, passes = [], []


def check(ok, msg):
    (passes if ok else failures).append(msg)


def check_dockerfile():
    text = (ROOT / "Dockerfile").read_text()
    lines = [ln.strip() for ln in text.splitlines() if ln.strip() and not ln.strip().startswith("#")]
    froms = [ln.split()[1] for ln in lines if ln.upper().startswith("FROM ")]
    check(bool(froms) and all(not f.endswith(":latest") and ":" in f for f in froms), "Dockerfile: pinned base image (no :latest)")
    users = [ln.split()[1] for ln in lines if ln.upper().startswith("USER ")]
    uid = users[-1].split(":")[0] if users else "0"
    check(uid.isdigit() and int(uid) != 0, "Dockerfile: final USER is numeric non-root")
    bad = [ln for ln in lines if re.match(r"(ENV|ARG)\s+\S*(PASSWORD|SECRET|TOKEN|ACCESS_KEY)\S*\s*=\s*\S+", ln, re.I)]
    check(not bad, "Dockerfile: no secrets in ENV/ARG")
    check(any(ln.upper().startswith("HEALTHCHECK") for ln in lines), "Dockerfile: HEALTHCHECK defined")


def containers(doc):
    return doc["spec"]["template"]["spec"].get("containers", [])


def check_manifests():
    for f in sorted((ROOT / "kubernetes" / "base").rglob("*.yaml")):
        if f.name == "secrets-example.yaml":
            continue
        for doc in yaml.safe_load_all(f.read_text()):
            if not doc:
                continue
            if doc.get("kind") == "Secret":
                check(False, f"{f.name}: Secret manifest must not live in kustomized base")
            if doc.get("kind") != "Deployment":
                continue
            n = doc["metadata"]["name"]
            pod = doc["spec"]["template"]["spec"]
            check(not pod.get("hostNetwork") and not pod.get("hostPID"), f"{n}: no hostNetwork/hostPID")
            for c in containers(doc):
                sc = c.get("securityContext", {})
                psc = pod.get("securityContext", {})
                check(bool(c.get("resources", {}).get("limits")), f"{n}: resource limits set")
                check("readinessProbe" in c and "livenessProbe" in c, f"{n}: readiness and liveness probes")
                check(sc.get("allowPrivilegeEscalation") is False, f"{n}: allowPrivilegeEscalation=false")
                check(not sc.get("privileged"), f"{n}: not privileged")
                check(sc.get("runAsNonRoot") or psc.get("runAsNonRoot"), f"{n}: runAsNonRoot")
                check(not str(c.get("image", "")).endswith(":latest"), f"{n}: image is not :latest")


def check_repo():
    gi = (ROOT / ".gitignore").read_text()
    for pat in (".env", "kubeconfig", "*.pem", "*.key"):
        check(pat in gi, f".gitignore covers {pat}")
    for k in (ROOT / "kubernetes").rglob("kustomization.yaml"):
        doc = yaml.safe_load(k.read_text()) or {}
        res = [str(r).lower() for r in doc.get("resources", [])]
        ok = not any("secret" in r for r in res) and "secretGenerator" not in doc
        check(ok, f"{k.parent.name}/kustomization.yaml: no Secret resources")


def main():
    check_dockerfile(); check_manifests(); check_repo()
    out = ROOT / "reports"; out.mkdir(exist_ok=True)
    lines = ["# Security policy validation", ""] + [f"- PASS: {m}" for m in passes] + [f"- **FAIL: {m}**" for m in failures]
    (out / "policy-report.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    print(f"\n{len(passes)} passed, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
