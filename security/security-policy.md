# Security Policy - Healthcare DevSecOps (PBL-III)

## Gates (all must pass before deployment in the VLE 9 pipeline)
| Gate | Tool | Fails when | Threshold variable |
|------|------|-----------|--------------------|
| SAST | Bandit | any finding >= level | `BANDIT_FAIL_LEVEL` (default HIGH) |
| Secrets | Gitleaks | any leak detected | - |
| Dependencies | pip-audit (+ optional OWASP Dependency-Check) | known vulnerable pin | `PIP_AUDIT_FAIL` (default true) |
| Image | Trivy | fixable HIGH/CRITICAL | `TRIVY_SEVERITY` (default HIGH,CRITICAL) |
| Policy-as-code | `security/validate_policy.py` | Dockerfile/manifest rule broken | - |

## Policy rules enforced by `validate_policy.py`
- Dockerfile: numeric non-root `USER`, pinned (non-`latest`) base image, no secrets in `ENV`/`ARG`.
- Kubernetes: resource limits, readiness+liveness probes, `allowPrivilegeEscalation=false`, not privileged,
  `runAsNonRoot`, no `hostNetwork`/`hostPID`, no `:latest` image, no Secret manifest inside kustomizations.
- Repo: `.gitignore` covers `.env`, kubeconfig and key files.

## Data handling
Only fictional patient data is used. Never load real patient information (PHI) into this project.

## Secrets
Never commit secrets. Use Jenkins credentials (`dockerhub-creds`, `kubeconfig-aws`) and Kubernetes Secrets created from the shell
(see `kubernetes/base/common/secrets-example.yaml`).

## RBAC recommendations
- Jenkins deploys with a namespace-scoped ServiceAccount (Role limited to deployments, services, configmaps, secrets, networkpolicies in `healthcare`), not cluster-admin.
- Developers: read-only (`view`) in the namespace; only the pipeline holds `edit`.
- `automountServiceAccountToken: false` on application pods (already set).
- Namespace enforces Pod Security `restricted`.
Example:
```
kubectl -n healthcare create serviceaccount jenkins-deployer
kubectl -n healthcare create role jenkins-deployer --verb=get,list,watch,create,update,patch,delete \
  --resource=deployments,services,configmaps,secrets,networkpolicies,pods,pods/portforward,replicasets
kubectl -n healthcare create rolebinding jenkins-deployer --role=jenkins-deployer --serviceaccount=healthcare:jenkins-deployer
```
(Namespace creation needs cluster scope; create the namespace once as an admin.)

## Exceptions
Accepted risks go in `.trivyignore` with a justification and expiry date.
