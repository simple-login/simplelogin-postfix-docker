#!/usr/bin/env bash

set -euo pipefail

if (( $# < 2 )); then
  echo "Usage: $0 <compose-file> <service> [service...]" >&2
  exit 1
fi

compose_file="$1"
shift

cleanup() {
  docker compose -f "$compose_file" down --volumes --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker compose -f "$compose_file" up --build --detach

for service in "$@"; do
  docker compose -f "$compose_file" wait "$service"
done
