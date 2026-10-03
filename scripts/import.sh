#!/usr/bin/env bash
# Load every JSON in ./workflows into n8n. Re-running overwrites workflows with the same id,
# so run export.sh first if you edited anything in the UI.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T n8n n8n import:workflow --separate --input=/workflows
echo "Done. Open http://localhost:5678, open each workflow, test with 'Execute workflow', then toggle Active."
