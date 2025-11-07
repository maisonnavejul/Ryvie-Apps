#!/bin/bash
# ----------------------------------------------------------
# Script: generate_ports_json.sh
# Description: Generate ports.json from docker-compose files,
#              listing all ports declared in each app.
# ----------------------------------------------------------

set -euo pipefail

# ------------------------------
# Check dependencies
# ------------------------------
command -v jq >/dev/null 2>&1 || { echo "❌ jq is not installed. Exiting."; exit 1; }

# ------------------------------
# Variables
# ------------------------------
OUTPUT_FILE="ports.json"

echo "🔌 Generating ${OUTPUT_FILE} from */docker-compose.yml..."

# Initialize empty JSON object
echo "{}" > "$OUTPUT_FILE"

# Loop over all docker-compose.yml files
for compose_file in */docker-compose.yml; do
  if [ ! -f "$compose_file" ]; then
    continue
  fi

  app_dir=$(basename "$(dirname "$compose_file")")
  echo "🔹 Processing app: $app_dir"

  # Extract ports using regex (format "host:container" with optional quotes)
  ports_found=$(grep -oP '- ["\']?\K\d+:\d+(?=["\']?)' "$compose_file" 2>/dev/null || true)
  
  if [ -z "$ports_found" ]; then
    echo "⚠️ No ports found in $app_dir"
    continue
  fi

  # Build JSON object for ports
  ports_object="{}"
  while IFS=: read -r host_port container_port; do
    ports_object=$(echo "$ports_object" | jq --arg hp "$host_port" --argjson cp "$container_port" '. + {($hp): $cp}')
  done <<< "$ports_found"

  # Add app entry to main JSON
  tmp=$(mktemp)
  jq --arg app "$app_dir" --argjson ports "$ports_object" '. + {($app): $ports}' "$OUTPUT_FILE" > "$tmp" && mv "$tmp" "$OUTPUT_FILE"
done

echo "✅ ports.json successfully generated!"