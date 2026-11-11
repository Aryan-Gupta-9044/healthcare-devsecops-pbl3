#!/usr/bin/env python3
"""Build reports/security-summary.md from whatever scan outputs exist."""
import json
from pathlib import Path

R = Path(__file__).resolve().parents[1] / "reports"


def load(name):
    p = R / name
    try:
        return json.loads(p.read_text()) if p.exists() and p.stat().st_size else None
    except ValueError:
        return None


rows = []
b = load("bandit.json")
if b is not None:
    c = {"HIGH": 0, "MEDIUM": 0, "LOW": 0}
    for r in b.get("results", []):
        c[r["issue_severity"]] += 1
    rows.append(("Bandit (SAST)", f"HIGH={c['HIGH']} MEDIUM={c['MEDIUM']} LOW={c['LOW']}"))
g = R / "gitleaks.json"
if g.exists():
    try:
        rows.append(("Gitleaks (secrets)", f"{len(json.loads(g.read_text() or '[]'))} leak(s)"))
    except ValueError:
        rows.append(("Gitleaks (secrets)", "report unreadable"))
a = load("pip-audit.json")
if a is not None:
    deps = a.get("dependencies", a if isinstance(a, list) else [])
    rows.append(("pip-audit (dependencies)", f"{sum(1 for d in deps if d.get('vulns'))} vulnerable package(s)"))
t = load("trivy-image.json")
if t is not None:
    c = {}
    for res in t.get("Results", []):
        for v in res.get("Vulnerabilities") or []:
            c[v["Severity"]] = c.get(v["Severity"], 0) + 1
    rows.append(("Trivy (image)", ", ".join(f"{k}={v}" for k, v in sorted(c.items())) or "no vulnerabilities at configured severity"))
p = R / "policy-report.md"
if p.exists():
    t = p.read_text()
    rows.append(("Policy validation", f"{t.count('- PASS')} passed, {t.count('FAIL:')} failed"))
md = ["# DevSecOps security summary", "", "| Check | Result |", "|---|---|"] + [f"| {k} | {v} |" for k, v in rows]
md += ["", "Detailed reports: bandit.txt/json, gitleaks.json, pip-audit.txt/json, trivy-image.txt/json, policy-report.md"]
R.mkdir(exist_ok=True)
(R / "security-summary.md").write_text("\n".join(md) + "\n")
print("\n".join(md))
