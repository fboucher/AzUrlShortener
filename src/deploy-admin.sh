#!/usr/bin/env bash
set -euo pipefail

# Deploy Api + TinyBlazorAdmin as an App Service
#
# For a single App Service, both projects need to be merged into one deployable
# web application. Until then, they can be deployed as separate App Services
# within the same App Service Plan.
#
# Usage:
#   ./deploy-admin.sh <resource-group> <location>

RG="${1:-rg-azurl-admin}"
LOC="${2:-eastus2}"
ENV_NAME="admin-${LOC}"

echo "=== Provisioning infrastructure ==="
az deployment group create \
  --resource-group "$RG" \
  --template-file infra/admin/main.bicep \
  --parameters environmentName="$ENV_NAME" location="$LOC"

ADMIN_NAME=$(az deployment group show --resource-group "$RG" -n main --query properties.outputs.WEB_APP_NAME.value -o tsv)

echo "=== Deploy Api ==="
cd Api
dotnet publish -c Release -o ../publish/admin
cd ..
zip -j publish/admin.zip publish/admin/*
az webapp deploy --resource-group "$RG" --name "$ADMIN_NAME" --type zip --src-path publish/admin.zip

echo "=== Done ==="
echo "API: https://${ADMIN_NAME}.azurewebsites.net"
