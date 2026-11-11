# GitHub setup (single repository)
1. Create an empty repo named `healthcare-devsecops-pbl3` on GitHub (no README/licence).
2. Unzip the project, then:
```bash
cd healthcare-devsecops-pbl3
git init -b main
git status --ignored            # confirm .venv/, reports/, *.zip, kubeconfig* are ignored
git add .
git commit -m "PBL-III: healthcare DevSecOps project (VLE 7, 8, 9)"
git remote add origin https://github.com/<your-user>/healthcare-devsecops-pbl3.git
git push -u origin main
```
3. Private repo? Create a PAT (read-only, this repo) and add Jenkins credential `github-creds`.
4. Before pushing run `python scripts/validate_project.py` (it fails on credential-looking strings).
5. If GitHub rejects a push because of secret scanning, remove the flagged value - never bypass protection.
