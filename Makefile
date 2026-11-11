.RECIPEPREFIX := >
.PHONY: setup test validate build-all vle7 blue green switch rollback security demo-fail demo-clean clean zip
setup:
> ./scripts/setup.sh --start-minikube
test:
> ./scripts/install-deps.sh test && .venv/bin/python -m pytest tests -v
validate:
> ./scripts/install-deps.sh all && .venv/bin/python scripts/validate_project.py
build-all:
> ./scripts/build.sh all
vle7:
> ./scripts/build.sh vle7 && ./scripts/deploy.sh vle7 && ./scripts/verify.sh vle7-k8s && ./scripts/verify.sh vle7-http
blue:
> ./scripts/build.sh blue && ./scripts/deploy.sh blue && ./scripts/verify.sh blue
green:
> ./scripts/build.sh green && ./scripts/deploy.sh green && ./scripts/verify.sh green
switch:
> ./scripts/blue-green-switch.sh green
rollback:
> ./scripts/rollback.sh blue
security:
> ./scripts/install-deps.sh security && ./scripts/security-scan.sh all
demo-fail:
> ./scripts/security-demo.sh inject && ./scripts/security-scan.sh bandit; ./scripts/security-scan.sh gitleaks; ./scripts/security-demo.sh remove
clean:
> ./scripts/cleanup.sh
