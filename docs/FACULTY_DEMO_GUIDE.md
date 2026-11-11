# Faculty demonstration sequence (~20 min)
**Prep (before the session):** `minikube start --cpus=2 --memory=2048 --cni=calico`, Jenkins running, three jobs created, repo pushed.
1. **Intro (1 min):** one repo, three pipelines, local Docker/Minikube; show `README.md` architecture and repo tree.
2. **VLE 7 (5 min):** Build `PBL3-VLE7-CICD`; narrate stages; then `kubectl get deployments,pods,services -n healthcare`; open the dashboard; add a sample patient; show `/health`.
3. **VLE 8 (7 min):** Build `PBL3-VLE8-BLUE-GREEN` with `APPROVAL_REQUIRED=true`. While waiting at approval: `kubectl get pods -n healthcare` (both colours), open Blue via port-forward,
   `kubectl get svc healthcare-service -n healthcare -o yaml | grep -A3 selector`. Approve -> refresh browser: v2.0.0 Green. Run again with `ACTION=rollback` (or `./scripts/rollback.sh blue`) -> Blue returns.
4. **VLE 9 (7 min):** Build `PBL3-VLE9-DEVSECOPS` with `DEMO_FAIL_GATE=true` -> show red Bandit/Gitleaks and no deployment; open archived reports. Rebuild with `false` -> all gates green, deployed; show `security-summary.md`.
5. **Close (1 min):** `kubectl -n healthcare get all`, mention optional AWS path (`docs/LOCAL_TO_AWS_MIGRATION.md`) and cost control.
Tip: keep screenshots from `screenshots/README.md` as a backup if the network or Docker is slow.
