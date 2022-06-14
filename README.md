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
Replace the parameter file in the command to deploy all master nodes and worker nodes. Actually, there is only name difference.
```
az deployment group create \
  --name <deployment group name> \
  --resource-group <resource group name> \
  --template-uri "https://raw.githubusercontent.com/msftjonw/CreateK8SFromScratch/main/template-k8s.json" \
  --parameters "https://raw.githubusercontent.com/msftjonw/CreateK8SFromScratch/main/parameters-k8smaster1.json"
```

## Option 2: Create Azure VMs with "Deploy to Azure" button
After clicking on the button "Deploy to Azure", login to the Azure subscription and click on "edit parameters" on the top middle. Load different parameter files to deploy all master nodes and worker nodes. Actually, there is only name difference.
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmsftjonw%2FCreateK8SFromScratch%2Fmain%2Ftemplate-k8s.json)
