#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

npm run db:local
npm run helm:install

echo "Waiting for Penpot rollout..."
for name in frontend backend exporter mcp; do
  kubectl rollout status "deployment/my-release-penpot-${name}" --timeout=180s
done

echo "Waiting for frontend HTTP..."
ok=0
for _ in $(seq 1 60); do
  if kubectl exec deploy/my-release-penpot-frontend -- wget -q -O /dev/null http://127.0.0.1:8080/; then
    ok=1
    break
  fi
  sleep 1
done

if [[ "$ok" -ne 1 ]]; then
  echo "Frontend did not become reachable on :8080" >&2
  exit 1
fi

echo "Penpot is ready at http://localhost:9001"
(sleep 1 && open http://localhost:9001) &
exec kubectl port-forward --address 127.0.0.1 svc/my-release-penpot 9001:8080
