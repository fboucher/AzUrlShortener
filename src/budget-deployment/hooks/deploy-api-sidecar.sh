#!/bin/sh
# deploy-api-sidecar.sh
#
# Builds the API container image using ACR Tasks (no local Docker daemon needed),
# pushes it to the project's ACR, then restarts the admin App Service so that
# App Service pulls the fresh image for the API sidecar container.
#
# Environment variables provided by azd:
#   AZURE_CONTAINER_REGISTRY_NAME  – ACR name (output from Bicep)
#   AZURE_ADMIN_APP_NAME           – Admin App Service name (output from Bicep)
#   AZURE_RESOURCE_GROUP           – Resource group name (set by azd)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Docker build context = src/ (solution root, two levels up from this script)
SRC_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -z "$AZURE_CONTAINER_REGISTRY_NAME" ]; then
  echo "ERROR: AZURE_CONTAINER_REGISTRY_NAME is not set. Run 'azd provision' first."
  exit 1
fi

if [ -z "$AZURE_ADMIN_APP_NAME" ]; then
  echo "ERROR: AZURE_ADMIN_APP_NAME is not set. Run 'azd provision' first."
  exit 1
fi

if [ -z "$AZURE_RESOURCE_GROUP" ]; then
  echo "ERROR: AZURE_RESOURCE_GROUP is not set. Run 'azd provision' first."
  exit 1
fi

echo ""
echo "==> Building and pushing API sidecar image to ACR: $AZURE_CONTAINER_REGISTRY_NAME"
echo "    Build context: $SRC_DIR"
echo "    Dockerfile:    Api/Dockerfile"
echo ""

# 'az acr build' runs the Docker build inside Azure (no local Docker required).
# The Dockerfile path is relative to the build context (SRC_DIR = src/).
az acr build \
  --registry "$AZURE_CONTAINER_REGISTRY_NAME" \
  --image "api:latest" \
  --file "Api/Dockerfile" \
  "$SRC_DIR"

echo ""
echo "==> Restarting admin site '$AZURE_ADMIN_APP_NAME' to pull the new API sidecar image..."
az webapp restart \
  --name "$AZURE_ADMIN_APP_NAME" \
  --resource-group "$AZURE_RESOURCE_GROUP"

echo ""
echo "==> API sidecar deployment complete."
echo "    The API is accessible only via http://localhost:8080 from within the"
echo "    site unit and is NOT reachable from the internet."
