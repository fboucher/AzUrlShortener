

# Deploy the budget solution

This guide explains how to deploy the budget-friendly version of AzUrlShortener. This deployment uses an Azure App Service for the admin website, an Azure Functions app for redirects, and an API container running as a private sidecar in the admin App Service.

## Prerequisites

Install the following tools before you begin:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- Git, if you are cloning the repository

You also need:

- An Azure subscription with permission to create resource groups and the resources in this deployment.
- A local copy of your fork or clone of the AzUrlShortener repository.
- The custom domain you will use for short URLs, including `https://`.
- The default redirect URL, including `https://`.

## First deployment

1. Sign in to Azure with both the Azure CLI and Azure Developer CLI:

	```bash
	az login
	azd auth login
	```

	Use the same account, or an account with access to the target subscription.

1. Change to the budget deployment directory:

	```bash
	cd src/budget-deployment
	```

	If you cloned the repository elsewhere, replace the path with your local repository path.

1. Provision the Azure resources and deploy the application:

	```bash
	azd up
	```

	During this command, `azd` asks you to select an Azure subscription and location, and to provide values for:

	- **Environment name**: Used in the resource group name. For example, an environment named `budget-prod` creates the resource group `rg-budget-prod`.
	- **Custom domain**: The complete domain for your short URLs, such as `https://c5m.ca`.
	- **Default redirect URL**: The destination used when a vanity URL does not exist or no vanity is supplied.

	`azd up` creates the resource group and required storage, App Service, Functions, and container registry resources. After provisioning, the post-provision hook builds the API image in Azure Container Registry and restarts the admin App Service so it can load the sidecar.

1. Open the URLs printed by `azd` when deployment completes. The admin website URL is the App Service URL, and the redirect service URL is the Azure Functions URL.

## Update an existing deployment

After making application changes, sign in and move to the deployment directory:

```bash
az login
azd auth login
cd /home/frank/gh/AzUrlShortener/src/budget-deployment
```

Deploy only the admin website and its related application files with:

```bash
azd deploy admin
```

To deploy all application services instead, use:

```bash
azd deploy
```

Use `azd provision` when the infrastructure definition has changed and the Azure resources need to be updated.

## Troubleshooting the API sidecar

The API sidecar image is normally built automatically by the `azd up` post-provision hook. If the image is missing or the hook did not complete, run the hook manually from `src/budget-deployment`:

```bash
sh hooks/deploy-api-sidecar.sh
```

The script builds the image with Azure Container Registry Tasks, so Docker does not need to be running locally. It then restarts the admin App Service.

If the admin website still has the old sidecar after the image is available, restart it manually:

```bash
az webapp restart \
  --name <admin-app-name> \
	--resource-group <resource-group-name>.
	The API sidecar is private and is reachable only by the admin application through `http://localhost:8081`; it is not exposed directly to the internet.


Replace `<admin-app-name>` and `<resource-group-name>` with the values from the deployment output or the Azure portal. The API sidecar is private and is reachable only by the admin application through `http://localhost:8081`; it is not exposed directly to the internet.