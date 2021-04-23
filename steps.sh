#0. Variables
SERVICE_PRINCIPAL_NAME="play-with-public-azure-ip-addresses"
SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
RESOURCE_GROUP_NAME="DATALAKE_RESOURCE_GROUP"
DATALAKE_STORE_NAME="DATALAKE_NAME"

# 1. Create the service principal for the resource group where the Data Lake Store Gen 1 is
az ad sp create-for-rbac --name $SERVICE_PRINCIPAL_NAME --role "Contributor" --scopes /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}
#Output example:
# {
#   "appId": "xxxxx-xxxx-xxx-xxx-xxxxxx",
#   "displayName": "play-with-public-azure-ip-addresses",
#   "name": "http://play-with-public-azure-ip-addresses",
#   "password": "RANDOM_PASSWORD",
#   "tenant": "YOUR_TENANT_ID"
# }

#Copy the output here
SP_APP_ID=""
SP_NAME=""
SP_PASSWORD=""
SP_TENANT_ID=""

# 2. Build the Docker image (locally)
docker build -t play-with-azure-public-ips .

# 3. Run the container (locally)
docker run -e SPUSERNAME=$SP_NAME \
    -e SPPASSWORD=$SP_PASSWORD \
    -e TENANT=$SP_TENANT_ID \
    -e RESOURCE_GROUP=$RESOURCE_GROUP_NAME \
    -e DLS_ACCOUNT_NAME=$DATALAKE_STORE_NAME \
    play-with-azure-public-ips

# 4. Create an Azure Container Registry
ACR_RG="Play-With-Public-Azure-IP-Addresses"
LOCATION="northeurope"
ACR_NAME="azuremantainance"
IMAGE_NAME="play-with-azure-public-ips"

az group create --name $ACR_RG --location $LOCATION
az acr create --resource-group $ACR_RG --name $ACR_NAME --sku Basic --admin-enabled true

# 5. Build the Docker image (Azure Container Registry)
az acr build --registry $ACR_NAME -g $ACR_RG --image $IMAGE_NAME .

REGISTRY_PASSWORD=$(az acr credential show -n $ACR_NAME -g $ACR_RG | jq -r '.passwords[] | select(.name=="password") | .value')

# 6. Run the container (Azure Container Registry)
az container create -g $ACR_RG \
    --name updateips \
    --image $ACR_NAME.azurecr.io/$IMAGE_NAME \
    --registry-login-server $ACR_NAME.azurecr.io \
    --registry-username $ACR_NAME \
    --registry-password $REGISTRY_PASSWORD \
    --environment-variables SPUSERNAME=$SP_NAME SPPASSWORD=$SP_PASSWORD TENANT=$SP_TENANT_ID RESOURCE_GROUP=$RESOURCE_GROUP_NAME DLS_ACCOUNT_NAME=$DATALAKE_STORE_NAME \
    --cpu 2 --memory 4 \
    --restart-policy Never
