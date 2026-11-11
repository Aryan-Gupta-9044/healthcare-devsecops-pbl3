# Viva questions (with short answers)

## VLE 7 - CI/CD with Jenkins and Kubernetes
1. What is CI/CD? Automating integration, testing and delivery of code changes.
2. Difference between Continuous Delivery and Deployment? Delivery stops at a manual release gate; deployment releases automatically.
3. What is a Jenkinsfile? Pipeline-as-code stored in Git.
4. Declarative vs scripted pipeline? Declarative has structured `pipeline{}` syntax; scripted is free-form Groovy.
5. What is a Jenkins agent? A node that executes the pipeline steps.
6. Why Docker? Reproducible, portable packaging of app plus dependencies.
7. Container vs VM? Containers share the host kernel and are lighter; VMs include a guest OS.
8. What is a Pod? Smallest deployable unit; one or more containers sharing network/storage.
9. Deployment vs Pod? Deployment manages replicas, rolling updates and self-healing of Pods.
10. What is a Service? Stable virtual IP/DNS and load balancing for a set of pods selected by labels.
11. ClusterIP vs NodePort vs LoadBalancer? Internal only / opens a port on every node / cloud load balancer (costly on AWS).
12. Readiness vs liveness probe? Readiness gates traffic; liveness restarts a stuck container.
13. Why set resource requests/limits? Scheduling fairness and protection from noisy neighbours.
14. How did Minikube get the image without a registry? `minikube image load` copies it into the cluster runtime.
15. What does `imagePullPolicy: Never` do? Uses only the local image; never pulls.
16. What does `kubectl apply` do? Declaratively creates/updates resources to match the manifest.
17. What is Kustomize? Template-free customisation of base manifests through overlays.
18. How does the pipeline verify the deployment? `rollout status`, `get` commands and HTTP checks of `/health` and `/api/status`.

## VLE 8 - Blue-Green deployment
1. What is Blue-Green deployment? Two identical environments; traffic is switched from the old (Blue) to the new (Green).
2. Benefits? Near-zero downtime and instant rollback.
3. Drawbacks? Double resource use during the release; data/schema changes need care.
4. Blue-Green vs Rolling update? Rolling replaces pods gradually in one Deployment; Blue-Green keeps two full Deployments.
5. Blue-Green vs Canary? Canary sends a small percentage of traffic first; Blue-Green flips all traffic.
6. How is the switch done here? Patching the Service selector `version: blue` -> `green`.
7. Why does the Service selector decide traffic? A Service routes only to pods whose labels match its selector.
8. Which labels do the pods carry? `app=healthcare` and `version=blue|green`.
9. How is rollback performed? Patch the selector back to blue; Blue pods were preserved.
10. Why verify Green before switching? So only healthy code receives users.
11. What is the manual approval stage for? A human gate (`input` step) before production traffic moves.
12. What happens if verification after the switch fails? `AUTO_ROLLBACK` runs `rollback.sh blue`.
13. How do you see which version serves traffic? `/api/status` or the page badge, plus `kubectl get svc -o yaml`.
14. Why are two image tags used? `1.0.0-blue` and `2.0.0-green` differ in baked version/colour.
15. What does `kubectl patch --type merge` do? Merges the given fields into the existing object.
16. What do `maxUnavailable: 0` and `maxSurge: 1` mean? During rolling updates no pod is removed before a new one is ready.
17. Can sessions break on switch? Yes for in-memory state; use shared storage/sticky strategy in production.

## VLE 9 - DevSecOps
1. What is DevSecOps? Integrating security checks into every stage of DevOps ("shift left").
2. What is SAST? Static analysis of source code without running it (Bandit).
3. What is SCA / dependency scanning? Finding known-vulnerable third-party libraries (pip-audit, Dependency-Check).
4. What does Gitleaks do? Detects hard-coded secrets in files and Git history.
5. What does Trivy scan? Image OS packages and libraries (CVEs), plus filesystem/IaC/secrets.
6. What is a CVE? A public identifier for a known vulnerability.
7. What is a security gate? A check that fails the pipeline if a threshold is exceeded.
8. How are thresholds configured? `BANDIT_FAIL_LEVEL`, `TRIVY_SEVERITY`, `PIP_AUDIT_FAIL`.
9. Why run as non-root? Limits the impact of a container compromise.
10. Why a slim base image? Smaller attack surface and fewer CVEs.
11. What is `readOnlyRootFilesystem`? The container cannot write to its filesystem (only mounted volumes such as /tmp).
12. What is a NetworkPolicy? Rules limiting pod network traffic; needs a CNI that enforces it.
13. Kubernetes Secret vs ConfigMap? Secret is for sensitive data (base64, access-controlled); ConfigMap for non-sensitive settings.
14. Are Kubernetes Secrets encrypted by default? No, only base64-encoded; enable encryption at rest / external secret stores.
15. What is RBAC? Role-based access control for who may do what in the cluster.
16. What is Pod Security `restricted`? Namespace policy forcing non-root, no privilege escalation, dropped capabilities.
17. How was a failed gate demonstrated safely? A fixture with a fake password and risky code is injected only in demo runs and never shipped.
18. Why not store credentials in Git? They leak via history and forks; use Jenkins credentials/Secrets.
19. Why is HIPAA-style data a concern? Patient data is sensitive; this project uses fictional data only.
