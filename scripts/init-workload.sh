#!/bin/sh

CLUSTER_NAME=$1
TENANT_ID=72f988bf-86f1-41af-91ab-2d7cd011db47

RESOURCE_GROUP="rg-aks-$CLUSTER_NAME"

echo Installing certificates ...
KEYVAULT_NAME=$(az deployment group show --resource-group $RESOURCE_GROUP -n cluster-stamp --query properties.outputs.keyVaultName.value -o tsv)
az keyvault set-policy --certificate-permissions import list get --upn $(az account show --query user.name -o tsv) -n $KEYVAULT_NAME  -o none

cat traefik-ingress-internal-aks-ingress-contoso-com-tls.crt traefik-ingress-internal-aks-ingress-contoso-com-tls.key > traefik-ingress-internal-aks-ingress-contoso-com-tls.pem
az keyvault certificate import -f traefik-ingress-internal-aks-ingress-contoso-com-tls.pem -n traefik-ingress-internal-aks-ingress-contoso-com-tls --vault-name $KEYVAULT_NAME  -o none

az keyvault delete-policy --upn $(az account show --query user.name -o tsv) -n $KEYVAULT_NAME -o none

export TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID=$(az deployment group show --resource-group $RESOURCE_GROUP -n cluster-stamp --query properties.outputs.aksIngressControllerUserManageIdentityResourceId.value -o tsv)
export TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az deployment group show --resource-group $RESOURCE_GROUP -n cluster-stamp --query properties.outputs.aksIngressControllerUserManageIdentityClientId.value -o tsv)

cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: aksic-to-keyvault-identity
  namespace: a0008
spec:
  type: 0
  resourceID: $TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID
  clientID: $TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID
---
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: aksic-to-keyvault-identity-binding
  namespace: a0008
spec:
  azureIdentity: aksic-to-keyvault-identity
  selector: traefik-ingress-controller
EOF

cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: aks-ingress-contoso-com-tls-secret-csi-akv
  namespace: a0008
spec:
  provider: azure
  parameters:
    usePodIdentity: "true"
    keyvaultName: "${KEYVAULT_NAME}"
    objects:  |
      array:
        - |
          objectName: traefik-ingress-internal-aks-ingress-contoso-com-tls
          objectAlias: tls.crt
          objectType: cert
        - |
          objectName: traefik-ingress-internal-aks-ingress-contoso-com-tls
          objectAlias: tls.key
          objectType: secret
    tenantId: "${TENANT_ID}"
EOF

kubectl apply -f https://raw.githubusercontent.com/tommygundersen/aks-secure-baseline/main/workload/traefik.yaml

kubectl wait --namespace a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=traefik-ingress-ilb --timeout=90s

kubectl apply -f https://raw.githubusercontent.com/tommygundersen/aks-secure-baseline/main/workload/aspnetapp.yaml

kubectl wait --namespace a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s