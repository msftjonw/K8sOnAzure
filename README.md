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
export rgname="RG-K8S"
az group create -l <location> -n ${rgname}
```

## Create Azure VMs
### Option 1: Create Azure VMs with pre-built ARM templates
```
export vmname=("k8smaster1" "k8smaster2" "k8sworker1" "k8sworker2" "k8sworker3")
for ((i=0; i<${#vmname[@]}; i++)); do \
az deployment group create \
  --name deployment-${vmname[i]} \
  --resource-group ${rgname} \
  --template-uri "https://raw.githubusercontent.com/msftjonw/CreateK8SFromScratch/main/template-k8s.json" \
  --parameters "https://raw.githubusercontent.com/msftjonw/CreateK8SFromScratch/main/parameters-${vmname[i]}.json"; \
done
```

### Option 2: Create Azure VMs with "Deploy to Azure" button
1. Click "Deploy to Azure"
2. Login to the Azure subscription
3. Click on "edit parameters" on the top middle.
4. Click on "load files". Select all downloaded parameters JSON file one by one to create master and worker nodes. <br/><br/>
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmsftjonw%2FCreateK8SFromScratch%2Fmain%2Ftemplate-k8s.json)

## Execute RunCommand in each Azure Linux VM to allow port 2222 for SSH
```
export vmlist=($(az vm list -g ${rgname} --query [].name -o tsv))
for ((i=0; i<${#vmlist[@]}; i++)); do \
az vm run-command invoke -g <resource group name> -n ${vmlist[i]} --command-id RunShellScript --scripts 'echo "Port 2222" >> /etc/ssh/sshd_config'; \
done
```

## Create a network security group and an an inbound security rule. 
```
export nsgname="NSG-K8S"
az network nsg create -g ${rgname} -n ${nsgname}
```
```
az network nsg rule create -g ${rgname} --nsg-name NSG-K8S -n Allow_SSH_2222 --priority 1000 \
    --destination-address-prefixes '*' --destination-port-ranges 2222 --access Allow \
    --protocol Tcp --description "Allow any IP to access port 2222."
```

##Associate the NSG with the virtual network/subnet.
```
vnetname=$(az network vnet list -g ${rgname} --query [].name -o tsv)
subnetname=$(az network vnet subnet list -g ${rgname} --vnet-name ${vnetname} --query [].name -o tsv)
az network vnet subnet update -g ${rgname} --vnet-name ${vnetname} -n ${subnetname} --network-security-grou
p ${nsgname}
```

## Set VMs' public IP to static and create a DNS name
```
export vmname=("k8smaster1" "k8smaster2" "k8sworker1" "k8sworker2" "k8sworker3")
export vmpiplist=($(az network public-ip list -g RG-K8S --query [].name -o tsv))
for ((i=0; i<${#vmpiplist[@]}; i++)); do \
az network public-ip update -g <resource group name> -n ${vmpiplist[i]} --dns-name ${vmname[i]} --allocation-method static ; \
done
```
