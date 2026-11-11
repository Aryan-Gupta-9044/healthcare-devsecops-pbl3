# VLE 8 - Automated Blue-Green Deployment using Jenkins, Kubernetes and Docker

## 1. Objective
Run two versions side by side and move live traffic with a real Service selector change, with approval and instant rollback.

## 2. Required software
Same as VLE 7.

## 3. Architecture
- `healthcare-blue` (pods `app=healthcare,version=blue`, image `healthcare-app:1.0.0-blue`, UI v1.0.0 blue)
- `healthcare-green` (pods `app=healthcare,version=green`, image `healthcare-app:2.0.0-green`, UI v2.0.0 green)
- Service `healthcare-service` selector `app=healthcare, version=<blue|green>` = the traffic switch.
Both Deployments coexist; Blue is never deleted so rollback is a one-line selector patch.

## 4. Implementation procedure
Job `PBL3-VLE8-BLUE-GREEN` (`jenkins/Jenkinsfile-vle8`). Stages: Checkout, Build Blue, Deploy Blue, Verify Blue, Build Green, Deploy Green,
Verify Green Health, Smoke Testing, **Manual Approval** (`APPROVAL_REQUIRED`), Switch Traffic to Green, Verify Traffic Reaches Green
(auto-rollback if it fails and `AUTO_ROLLBACK=true`), Rollback (run with `ACTION=rollback`).

## 5. Exact commands
```bash
./scripts/build.sh all
./scripts/deploy.sh blue && ./scripts/verify.sh blue
./scripts/deploy.sh green && ./scripts/verify.sh green
kubectl get pods -n healthcare
kubectl get services -n healthcare
kubectl get deployments -n healthcare
kubectl get service healthcare-service -n healthcare -o yaml     # selector.version: blue
kubectl -n healthcare port-forward svc/healthcare-service 8081:80  # browser: http://localhost:8081  (Blue)

./scripts/blue-green-switch.sh green        # SWITCH (patches the selector)
kubectl get service healthcare-service -n healthcare -o yaml     # selector.version: green
./scripts/rollback.sh blue                  # ROLLBACK
```
The switch itself is: `kubectl -n healthcare patch svc healthcare-service --type merge -p '{"spec":{"selector":{"app":"healthcare","version":"green"}}}'`

## 6. Expected output (typical)
Two Deployments `healthcare-blue 1/1`, `healthcare-green 1/1`; Service selector changes `blue` -> `green`;
browser/`/api/status` changes from `"version":"1.0.0","color":"blue"` to `"version":"2.0.0","color":"green"`; rollback returns to blue.

## 7. Verification
`verify.sh traffic green` checks both the selector and the live response via the Service. Pod name shown on the page changes with the colour.

## 8. Screenshots to capture
Blue page; `get deployments` showing both; approval prompt; Green page; service YAML before/after; rollback to Blue.

## 9. Result
Zero-downtime release switch and instant rollback driven by Jenkins, with no simulated steps.

## 10. Common errors and fixes
"no ready replicas - refusing to switch" (Green unhealthy; check `kubectl describe pod`); browser caching (hard refresh); re-running Deploy Blue keeps the live selector (by design).
