#!/bin/bash

# Loading my environment variables from grafana.env file in the arborescence.
if [[ -f grafana.env ]]; then
    export $(grep -v '^#' grafana.env | xargs)
else
    echo "Error: grafana.env file not found!"
    exit 1
fi

GRAFANA_URL="http://$SERVER_IP:3000"

if [[ ! -f "$DASHBOARD_FILE_PATH" ]]; then
    echo "Error: Dashboard file not found: $DASHBOARD_FILE_PATH"
    exit 1
fi

echo "Importing dashboard to Grafana at $GRAFANA_URL..."
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -d @"$DASHBOARD_FILE_PATH" \
  "$GRAFANA_URL/api/dashboards/db"

echo "Dashboard imported successfully!"
