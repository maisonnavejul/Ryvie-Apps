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
command -v yq >/dev/null 2>&1 || { echo "❌ yq is not installed. Exiting."; exit 1; }

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

  # Extract all ports from all services and flatten them
  ports_json=$(yq -o=json '.services | to_entries | map(select(.value.ports != null) | .value.ports) | flatten | map(select(. != null))' "$compose_file")
  
  # Check if any ports were found
  if [ "$ports_json" = "[]" ] || [ "$ports_json" = "null" ]; then
    echo "⚠️ No ports found in $app_dir"
    continue
  fi

  # Convert ports array to object with host:container mapping
  ports_object=$(echo "$ports_json" | jq -r 'map(
    if type == "string" then
      . | split(":") | 
      if length == 2 then
        {(.[0]): (.[1] | tonumber? // .)}
      elif length == 1 then
        {(.[0]): (.[0] | tonumber? // .)}
      else
        empty
      end
    elif type == "object" and .published and .target then
      {(.published | tostring): (.target | tonumber? // .target)}
    else
      empty
    end
  ) | add // {}')

  # Add app entry to main JSON
  tmp=$(mktemp)
  jq --arg app "$app_dir" --argjson ports "$ports_object" '. + {($app): $ports}' "$OUTPUT_FILE" > "$tmp" && mv "$tmp" "$OUTPUT_FILE"
done

echo "✅ ports.json successfully generated!"