#!/usr/bin/env python3
"""Static project validation: syntax, YAML, referenced files, credentials, optional kustomize render."""
import re
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SKIP = {".venv", ".git", "reports", ".render", "__pycache__"}
results = []


def files(pattern):
    return [p for p in ROOT.rglob(pattern) if not (set(p.relative_to(ROOT).parts) & SKIP)]


def rec(name, ok, detail=""):
    results.append((name, ok, detail))


def balanced(text):
    text = re.sub(r"'''.*?'''|\"\"\".*?\"\"\"", "", text, flags=re.S)
    text = re.sub(r"//[^\n]*|#[^\n]*", "", text)
    text = re.sub(r"'(?:\\.|[^'\\\n])*'|\"(?:\\.|[^\"\\\n])*\"", "", text)
    return all(text.count(a) == text.count(b) for a, b in ("{}", "()", "[]"))


REQUIRED = """app/app.py app/config.py app/requirements.txt app/templates/index.html app/static/css/style.css app/static/js/app.js
tests/test_app.py tests/requirements-test.txt docker/Dockerfile Dockerfile docker-compose.yml Jenkinsfile Makefile README.md progress.md
jenkins/Jenkinsfile-vle7 jenkins/Jenkinsfile-vle8 jenkins/Jenkinsfile-vle9 jenkins/shared/common.groovy
security/trivy.yaml security/gitleaks.toml security/security-policy.md .gitignore .dockerignore .gitattributes .trivyignore
scripts/setup.sh scripts/setup.ps1 scripts/build.sh scripts/deploy.sh scripts/deploy.ps1 scripts/blue-green-switch.sh scripts/rollback.sh
scripts/security-scan.sh scripts/cleanup.sh scripts/verify.sh screenshots/README.md
docs/VLE7_IMPLEMENTATION.md docs/VLE8_IMPLEMENTATION.md docs/VLE9_IMPLEMENTATION.md docs/JENKINS_SETUP.md docs/GITHUB_SETUP.md
docs/AWS_OPTIONAL_SETUP.md docs/ENVIRONMENT_VARIABLES.md docs/FACULTY_DEMO_GUIDE.md docs/VIVA_QUESTIONS.md docs/TROUBLESHOOTING.md docs/LOCAL_TO_AWS_MIGRATION.md""".split()
missing = [f for f in REQUIRED if not (ROOT / f).exists()]
rec("required files present", not missing, ", ".join(missing))

bad = []
for p in files("*.py"):
    try:
        compile(p.read_text(), str(p), "exec")
    except Exception as e:  # noqa: BLE001
        bad.append(f"{p.name}: {e}")
rec("python syntax", not bad, "; ".join(bad))

bad = []
for p in files("*.y*ml"):
    try:
        list(yaml.safe_load_all(p.read_text()))
    except Exception as e:  # noqa: BLE001
        bad.append(f"{p.relative_to(ROOT)}: {str(e)[:80]}")
rec("yaml syntax", not bad, "; ".join(bad))

bad = [p.name for p in files("*.sh") if subprocess.run(["bash", "-n", str(p)]).returncode]
rec("shell syntax (bash -n)", not bad, ", ".join(bad))

jf = [p for p in files("Jenkinsfile*")] + files("*.groovy")
rec("jenkinsfile structure (balanced brackets)", all(balanced(p.read_text()) for p in jf), "")
refs = set()
for p in jf + files("Makefile"):
    refs |= set(re.findall(r"scripts/[A-Za-z0-9_.-]+\.(?:sh|py)", p.read_text()))
rec("scripts referenced by pipelines exist", all((ROOT / r).exists() for r in refs), ", ".join(r for r in refs if not (ROOT / r).exists()))
rec("pipelines load shared groovy", all("jenkins/shared/common.groovy" in p.read_text() for p in jf if p.name.startswith("Jenkinsfile-")), "")

bad = [p.name for p in files("*.ps1") if not (balanced(p.read_text()) and "$ErrorActionPreference" in p.read_text())]
rec("powershell structure (balanced, strict errors)", not bad, ", ".join(bad))

pat = re.compile(r"AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|aws_secret_access_key\s*=\s*\S+|ghp_[A-Za-z0-9]{36}|dckr_pat_[A-Za-z0-9_-]{20,}")
hits = [str(p.relative_to(ROOT)) for p in ROOT.rglob("*") if p.is_file() and not (set(p.relative_to(ROOT).parts) & SKIP)
        and "fixtures" not in p.parts and p.suffix not in (".zip", ".png", ".jpg") and pat.search(p.read_text(errors="ignore"))]
rec("no hardcoded credentials", not hits, ", ".join(hits))

tool = shutil.which("kustomize") and ["kustomize", "build"] or shutil.which("kubectl") and ["kubectl", "kustomize"]
if tool:
    bad = []
    for env in ("local", "aws"):
        for t in ("common", "vle7", "blue", "green"):
            r = subprocess.run(tool + [str(ROOT / "kubernetes/overlays" / env / t)], capture_output=True, text=True)
            if r.returncode:
                bad.append(f"{env}/{t}")
    rec("kustomize renders all 8 overlays", not bad, ", ".join(bad))
else:
    print("note: kustomize/kubectl not found - overlay render check skipped")

for n, ok, d in results:
    print(f"[{'PASS' if ok else 'FAIL'}] {n} {d}")
sys.exit(0 if all(ok for _, ok, _ in results) else 1)
