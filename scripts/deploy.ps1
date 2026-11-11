<#
 Usage: .\scripts\deploy.ps1 -Target vle7|blue|green [-DeployEnv local|aws] [-Namespace healthcare] [-Image healthcare-app]
        [-Tag 1.0.0] [-BlueVersion 1.0.0] [-GreenVersion 2.0.0] [-Context <kube-context>]
 Renders the same Kustomize overlays as deploy.sh and applies them. Existing namespaces are left untouched.
#>
param(
  [ValidateSet("vle7", "blue", "green")][string]$Target = "vle7",
  [ValidateSet("local", "aws")][string]$DeployEnv = "local",
  [string]$Namespace = "healthcare", [string]$Image = "healthcare-app", [string]$Tag = "1.0.0",
  [string]$BlueVersion = "1.0.0", [string]$GreenVersion = "2.0.0", [string]$Context = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$kc = @(); if ($Context) { $kc = @("--context", $Context) }
function Invoke-Kube { kubectl @kc @args; if ($LASTEXITCODE -ne 0) { throw "kubectl $args failed" } }

function Render([string]$t) {
  $dir = Join-Path $root "kubernetes\.render\$t-$DeployEnv"; New-Item -ItemType Directory -Force $dir | Out-Null
  $lines = @("apiVersion: kustomize.config.k8s.io/v1beta1", "kind: Kustomization", "namespace: $Namespace", "resources:", "  - ../../overlays/$DeployEnv/$t")
  switch ($t) {
    "vle7"  { $lines += @("images:", "  - name: healthcare-app", "    newName: $Image", "    newTag: `"$Tag`"") }
    "blue"  { $lines += @("images:", "  - name: healthcare-app-blue", "    newName: $Image", "    newTag: `"$BlueVersion-blue`"") }
    "green" { $lines += @("images:", "  - name: healthcare-app-green", "    newName: $Image", "    newTag: `"$GreenVersion-green`"") }
  }
  Set-Content -Path (Join-Path $dir "kustomization.yaml") -Value $lines -Encoding ascii
  return (kubectl @kc kustomize $dir) -join "`n"
}

kubectl @kc get namespace $Namespace *> $null
if ($LASTEXITCODE -ne 0) {
  Invoke-Kube create namespace $Namespace
  Invoke-Kube label namespace $Namespace app.kubernetes.io/part-of=healthcare-devsecops-pbl3 pod-security.kubernetes.io/enforce=restricted
} else { Write-Host "namespace $Namespace exists - left untouched" }

(Render "common") | kubectl @kc apply -f -
if ($Target -eq "blue") { $prev = kubectl @kc -n $Namespace get svc healthcare-service -o jsonpath='{.spec.selector.version}' 2>$null }
(Render $Target) | kubectl @kc apply -f -
if ($Target -eq "blue" -and $prev -and $prev -ne "blue") {
  Write-Host "service already routes to $prev - preserving it"
  $patch = '{"spec":{"selector":{"version":"' + $prev + '"}}}'
  Invoke-Kube -n $Namespace patch svc healthcare-service --type merge -p $patch
}
$dep = @{ vle7 = "healthcare-cicd"; blue = "healthcare-blue"; green = "healthcare-green" }[$Target]
Invoke-Kube -n $Namespace rollout status "deployment/$dep" --timeout=180s
Invoke-Kube -n $Namespace get deployments, pods, services
