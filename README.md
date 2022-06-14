This Git repository is a technical guide for creating a Kubernetes cluster on Azure VMs.

# Create Azure VM with ARM template <br/>

## Install Azure CLI in the local machine
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli#install

## Clone the GitHub repository on the local machine
```
git clone 
```

## Login to Azure
```
az login --use-device-code
```

## Select the right Azure subscription
```
az account set -s <subscription ID or subscription name>
```

## Create a resource group
```
az group create -l <location> -n <resource group name>
```
For example:
```
az group create -l westus3 -n RG-K8S
```

## Option 1: Create Azure VMs with pre-built ARM templates
```
az deployment group create \
  --name <deployment group name> \
  --resource-group <resource group name> \
  --template-uri "" \
  --parameters ""
```

## Option 2: Create Azure VMs with "Deploy to Azure" button
