# Optional AWS setup (cost-minimised) - nothing is provisioned automatically
AWS is **not needed** for any VLE; local Docker + Jenkins + Minikube satisfies all three. Use AWS only for an extra demo.
Full step-by-step: `LOCAL_TO_AWS_MIGRATION.md`. This page = guard-rails.

## Do NOT create
EKS, NAT Gateways, Application/Network Load Balancers, RDS, large EC2 types, Elastic IPs you forget about.

## Minimum recommended
One EC2 Linux instance running **k3s** (single node): `t3.small` (2 GiB) recommended; `t3.micro` (1 GiB) is tight but can run 1 replica with Traefik disabled.
Check your own account's free-tier/credit terms for eligible types. 20 GiB gp3 volume. Stop the instance when not demoing; **terminate** it and delete the volume afterwards.

## Security group (inbound)
| Port | Source | Purpose |
|---|---|---|
| 22 | your public IP /32 | SSH |
| 6443 | your public IP /32 (or Jenkins host IP) | kubectl API |
| 30000-32767 | your public IP /32 | NodePort to view the app |
No `0.0.0.0/0` rules. A public IPv4 address can incur a small hourly charge.

## SSH
`chmod 400 key.pem && ssh -i key.pem ubuntu@<EC2_PUBLIC_IP>` (keep the `.pem` outside the repo; `.gitignore` blocks `*.pem`).

## AWS credential handling
The project needs no AWS access keys. If you use the AWS CLI to start/stop the instance, configure it on your workstation (`aws configure` or SSO); never in Git, Jenkinsfiles or Docker images.

## Cost hygiene
Create a Budget alert (e.g. low USD threshold) before launching. Tag the instance `project=pbl3`. After the demo see the cleanup section of `LOCAL_TO_AWS_MIGRATION.md`.
