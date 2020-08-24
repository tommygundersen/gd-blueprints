#!/bin/sh

CURRENT_DIR=$PWD
BASE_DIR=/mnt/c/demo/gd/clusters
CLUSTER_NAME=$1
LOCATION=westeurope
GEOREDUNDANCY_LOCATION=northeurope
AKS_LOCATION=westeurope
FLUX_REPO=https://github.com/tommygundersen/gd-blueprints.git

SUBSCRIPTION_ID=b210486c-915f-4c73-bf87-12f399820ebb
K8S_RBAC_AAD_PROFILE_TENANTID=9a015b64-0784-4076-a505-0db87f1c9ead
AKS_CLUSTER_DEPLOYMENT_TENANTID=72f988bf-86f1-41af-91ab-2d7cd011db47

echo Logging into Azure AD Tenant to establish Cluster AzureAD RBAC Groups ...
az login --allow-no-subscriptions -t $K8S_RBAC_AAD_PROFILE_TENANTID -o none && \
K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME=$(az ad signed-in-user show --query 'userPrincipalName' | cut -d '@' -f 2 | sed 's/\"//')

echo Creating group add-to-$CLUSTER_NAME-cluster-admin ...
K8S_RBAC_AAD_ADMIN_GROUP_OBJECTID=$(az ad group create --display-name add-to-$CLUSTER_NAME-cluster-admin --mail-nickname add-to-$CLUSTER_NAME-cluster-admin --query objectId -o tsv)
echo $K8S_RBAC_AAD_ADMIN_GROUP_OBJECTID group created. Add admins to this group.

echo Logging into AKS Cluster deployment tenant ...
az login -t $AKS_CLUSTER_DEPLOYMENT_TENANTID -o none
az account set -s $SUBSCRIPTION_ID

echo Getting network information for deployment ...
TARGET_VNET_RESOURCE_ID=$(az deployment group show -g rg-gd-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.clusterVnetResourceId.value -o tsv)
echo Will deploy cluster into VNET $TARGET_VNET_RESOURCE_ID ...

mkdir -p $BASE_DIR
echo Creating GitHub repo ...
curl -u $GITHUB_CREDENTIALS https://api.github.com/user/repos -d "{\"name\":\"aks-$CLUSTER_NAME\", \"private\": true, \"auto_init\": true}"

WORKING_DIR=$BASE_DIR/aks-$CLUSTER_NAME

echo Cloning into $BASE_DIR ...
git clone https://$GITHUB_CREDENTIALS@github.com/tommygundersen/aks-$CLUSTER_NAME.git $BASE_DIR/aks-$CLUSTER_NAME

echo Creating directory $WORKING_DIR/.github/workflows
mkdir -p $WORKING_DIR/.github/workflows

cd $CURRENT_DIR

echo Creating Github Action for Cluster deployment ...
cat ../github-workflows/aks-deploy.yaml | \
    sed "s#<resource-group-location>#$LOCATION#g" | \
    sed "s#<resource-group-name>#rg-aks-$CLUSTER_NAME#g" | \
    sed "s#<resource-group-localtion>#$LOCATION#g" | \
    sed "s#<geo-redundancy-location>#$GEOREDUNDANCY_LOCATION#g" | \
    sed "s#<cluster-spoke-vnet-resource-id>#$TARGET_VNET_RESOURCE_ID#g" | \
    sed "s#<tenant-id-with-user-admin-permissions>#$K8S_RBAC_AAD_PROFILE_TENANTID#g" | \
    sed "s#<azure-ad-aks-admin-group-object-id>#$K8S_RBAC_AAD_ADMIN_GROUP_OBJECTID#g" \
    > $WORKING_DIR/.github/workflows/aks-deploy.yaml

cp ../cluster-deployment/*.* $WORKING_DIR
mkdir $WORKING_DIR/cluster-baseline-settings
cp ../cluster-baseline-settings/ns-cluster-baseline-settings.yaml $WORKING_DIR/cluster-baseline-settings/ns-cluster-baseline-settings.yaml
cp ../cluster-baseline-settings/flux.yaml $WORKING_DIR/cluster-baseline-settings/flux.yaml

cd $WORKING_DIR
git add .
git commit -m "initial commit"
git push origin HEAD:kick-off-workflow

cd $CURRENT_DIR