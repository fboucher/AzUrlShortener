

cd src/budget-deployment

azd up




az login
cd /home/frank/gh/AzUrlShortener/src/budget-deployment
azd deploy admin or azd deploy
if the API sidecar image is missing, run:
sh hooks/deploy-api-sidecar.sh
if needed, restart the app:
az webapp restart --name <admin-app-name> --resource-group <rg-name>