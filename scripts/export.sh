#!/usr/bin/env bash
# Save workflows edited in the UI back to ./workflows (keep them in git).
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T n8n n8n export:workflow --all --separate --output=/workflows
echo "Exported to ./workflows"
