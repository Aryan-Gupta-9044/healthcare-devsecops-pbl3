#!/usr/bin/env bash
# Usage: security-demo.sh inject|remove  - controlled failed-gate demo using a safe fixture.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; T="$ROOT/app/_demo_insecure.py"
case "${1:-}" in
  inject) cp "$ROOT/security/fixtures/insecure_sample.py.fixture" "$T"; echo "fixture injected -> $T (remember: remove)";;
  remove) rm -f "$T"; echo "fixture removed";;
  *) echo "usage: $0 inject|remove"; exit 2;;
esac
