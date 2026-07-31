#!/usr/bin/env bash
set -euo pipefail

# Deploy FunctionsLight as a real Azure Function App
# Prerequisites:
#   - Azure CLI logged in (az login)
#   - Resource group created
#
# Usage:
#   ./deploy-redirect.sh <resource-group> <location>

RG="${1:-rg-azurl-redirect}"
LOC="${2:-eastus2}"
ENV_NAME="redirect-${LOC}"

echo "=== Provisioning infrastructure ==="
az deployment group create \
  --resource-group "$RG" \
  --template-file infra/redirect/main.bicep \
  --parameters environmentName="$ENV_NAME" location="$LOC" DefaultRedirectUrl="https://azure.com"

# Get outputs
FUNC_NAME=$(az deployment group show --resource-group "$RG" -n main --query properties.outputs.FUNCTION_APP_NAME.value -o tsv)

echo "=== Publishing FunctionsLight ==="
cd FunctionsLight
dotnet publish -c Release -o ../publish/redirect
cd ..

func azure functionapp publish "$FUNC_NAME" --dotnet-isolated

echo "=== Done ==="
echo "Function App: https://${FUNC_NAME}.azurewebsites.net"
