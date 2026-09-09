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

# azd may not export these variables into the shell inside a hook, even when the
# environment file exists. Load the environment file explicitly from the project
# root's .azure directory, not from the hooks folder.
ENV_FILE=""
if [ -n "${AZURE_ENV_NAME:-}" ] && [ -f "$SCRIPT_DIR/../.azure/${AZURE_ENV_NAME}/.env" ]; then
  ENV_FILE="$SCRIPT_DIR/../.azure/${AZURE_ENV_NAME}/.env"
fi

if [ -z "$ENV_FILE" ]; then
  for candidate in "$SCRIPT_DIR/../.azure"/*/.env; do
    if [ -f "$candidate" ]; then
      ENV_FILE="$candidate"
      break
    fi
  done
fi

if [ -n "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

# Fallback for azd hook shells that don't export env vars automatically.
if [ -z "$AZURE_RESOURCE_GROUP" ] && [ -n "$AZURE_ENV_NAME" ]; then
  # This project names the resource group as rg-<environmentName>
  AZURE_RESOURCE_GROUP="rg-${AZURE_ENV_NAME}"
fi

if [ -z "$AZURE_RESOURCE_GROUP" ]; then
  AZURE_RESOURCE_GROUP="$(azd env get-values 2>/dev/null | awk -F= '/^AZURE_RESOURCE_GROUP=/{print $2}' | tr -d '"' || true)"
fi

if [ -z "$AZURE_ADMIN_APP_NAME" ]; then
  AZURE_ADMIN_APP_NAME="$(azd env get-values 2>/dev/null | awk -F= '/^AZURE_ADMIN_APP_NAME=/{print $2}' | tr -d '"' || true)"
fi

if [ -z "$AZURE_CONTAINER_REGISTRY_NAME" ]; then
  AZURE_CONTAINER_REGISTRY_NAME="$(azd env get-values 2>/dev/null | awk -F= '/^AZURE_CONTAINER_REGISTRY_NAME=/{print $2}' | tr -d '"' || true)"
fi

if [ -z "$AZURE_RESOURCE_GROUP" ]; then
  echo "ERROR: AZURE_RESOURCE_GROUP is not set. Run 'azd provision' first."
  exit 1
fi

if [ -z "$AZURE_ADMIN_APP_NAME" ]; then
  echo "ERROR: AZURE_ADMIN_APP_NAME is not set. Run 'azd provision' first."
  exit 1
fi

if [ -z "$AZURE_CONTAINER_REGISTRY_NAME" ]; then
  AZURE_CONTAINER_REGISTRY_NAME="$(az acr list -g "$AZURE_RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null || true)"
fi

if [ -z "$AZURE_CONTAINER_REGISTRY_NAME" ]; then
  echo "ERROR: AZURE_CONTAINER_REGISTRY_NAME is not set and no registry was found in resource group '$AZURE_RESOURCE_GROUP'. Run 'azd provision' first."
  exit 1
fi

DOCKERFILE_PATH="Api/Dockerfile"
if [ ! -f "$SRC_DIR/$DOCKERFILE_PATH" ]; then
  echo "ERROR: Dockerfile not found at '$SRC_DIR/$DOCKERFILE_PATH'."
  exit 1
fi

echo ""
echo "==> Building and pushing API sidecar image to ACR: $AZURE_CONTAINER_REGISTRY_NAME"
echo "    Build context: $SRC_DIR"
echo "    Dockerfile:    $DOCKERFILE_PATH"
echo ""

# 'az acr build' runs the Docker build inside Azure (no local Docker required).
# Ensure the current working directory matches the build context so the relative
# Dockerfile path resolves consistently regardless of the hook's shell location.
(
  cd "$SRC_DIR"
  az acr build \
    --registry "$AZURE_CONTAINER_REGISTRY_NAME" \
    --image "api:latest" \
    --file "$DOCKERFILE_PATH" \
    .
)

echo ""
echo "==> Restarting admin site '$AZURE_ADMIN_APP_NAME' to pull the new API sidecar image..."
az webapp restart \
  --name "$AZURE_ADMIN_APP_NAME" \
  --resource-group "$AZURE_RESOURCE_GROUP"

echo ""
echo "==> API sidecar deployment complete."
echo "    The API is accessible only via http://localhost:8081 from within the"
echo "    site unit and is NOT reachable from the internet."
