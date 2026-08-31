#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USERS_FILE="${1:-$ROOT/users.txt}"
DEFAULT_PASSWORD="${PENPOT_SEED_PASSWORD:-penpot1234}"
BACKEND="deploy/my-release-penpot-backend"

if [[ ! -f "$USERS_FILE" ]]; then
  echo "Users file not found: $USERS_FILE" >&2
  exit 1
fi

echo "Waiting for Penpot PREPL..."
ok=0
for _ in $(seq 1 60); do
  if kubectl exec "$BACKEND" -- python3 -c 'import socket; socket.create_connection(("127.0.0.1", 6063), 2).close()' >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 2
done

if [[ "$ok" -ne 1 ]]; then
  echo "PREPL is not reachable. Run npm start first so flags include enable-prepl-server." >&2
  exit 1
fi

created=0
skipped=0
failed=0

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%$'\r'}"
  [[ -z "$line" || "$line" == \#* ]] && continue

  IFS=',' read -r email fullname password <<<"$line"
  email="$(echo "$email" | xargs)"
  fullname="$(echo "${fullname:-}" | xargs)"
  password="$(echo "${password:-}" | xargs)"

  [[ -z "$email" ]] && continue
  [[ -z "$fullname" ]] && fullname="${email%@*}"
  [[ -z "$password" ]] && password="$DEFAULT_PASSWORD"

  if [[ ${#password} -lt 8 ]]; then
    echo "Skip $email: password must be at least 8 characters" >&2
    failed=$((failed + 1))
    continue
  fi

  if out="$(kubectl exec "$BACKEND" -- python3 manage.py create-profile \
    -e "$email" \
    -n "$fullname" \
    -p "$password" \
    --skip-tutorial \
    --skip-walkthrough 2>&1)"; then
    echo "$out"
    created=$((created + 1))
  elif echo "$out" | grep -qiE 'already|exists|unique|duplicate'; then
    echo "Exists: $email"
    skipped=$((skipped + 1))
  else
    echo "Failed $email: $out" >&2
    failed=$((failed + 1))
  fi
done < "$USERS_FILE"

echo "Seed complete. created=$created skipped=$skipped failed=$failed"
echo "Log in at http://localhost:9001 with email + password."
