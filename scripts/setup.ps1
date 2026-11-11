<#
 Windows PowerShell bootstrap (safe to re-run). Usage:  .\scripts\setup.ps1 [-StartMinikube]
 Mirrors scripts/setup.sh: checks tools, builds the image, loads it into Minikube, deploys, verifies health.
#>
param([switch]$StartMinikube, [string]$Namespace = "healthcare", [string]$Image = "healthcare-app", [string]$Tag = "1.0.0")
$ErrorActionPreference = "Stop"
function Test-Tool($name) { if (Get-Command $name -ErrorAction SilentlyContinue) { Write-Host "  [ok] $name" } else { Write-Host "  [missing] $name"; return $false }; return $true }
$missing = $false
foreach ($t in "docker", "kubectl", "minikube") { if (-not (Test-Tool $t)) { $missing = $true } }
if ($missing) { throw "Install the missing tools first (see docs/JENKINS_SETUP.md)." }
docker info *> $null; if ($LASTEXITCODE -ne 0) { throw "Docker daemon is not reachable." }
minikube status *> $null
if ($LASTEXITCODE -ne 0) {
  if ($StartMinikube) { minikube start --cpus=2 --memory=2048 --cni=calico }
  else { throw "Minikube is not running. Run: minikube start --cpus=2 --memory=2048 --cni=calico  (or use -StartMinikube)" }
}
if ($env:JENKINS_URL) {
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 "$($env:JENKINS_URL)/login" | Out-Null; Write-Host "  [ok] Jenkins reachable" }
  catch { Write-Host "  [warn] Jenkins not reachable at $($env:JENKINS_URL)" }
} else { Write-Host "  [info] JENKINS_URL not set - skipping Jenkins check" }

$root = Split-Path -Parent $PSScriptRoot
docker build -f "$root\Dockerfile" --build-arg APP_VERSION=$Tag --build-arg DEPLOYMENT_COLOR=standard -t "${Image}:${Tag}" $root
if ($LASTEXITCODE -ne 0) { throw "docker build failed" }
minikube image load "${Image}:${Tag}"
& "$PSScriptRoot\deploy.ps1" -Target vle7 -Namespace $Namespace -Image $Image -Tag $Tag
Write-Host "Done. Open it with:  minikube service healthcare-cicd-service -n $Namespace"
