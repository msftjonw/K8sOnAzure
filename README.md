# This Git repository is a technical guide for creating a Kubernetes cluster with Azure VMs.

## Install Azure CLI in the local machine
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli#install

## Clone the GitHub repository on the local machine
```
git clone 
```

## Login to Azure with an user or AAD service principal with Azure RBAC Contributor permissions.
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
export location="westus3" #pick any Azure location
az group create -l ${location} -n ${rgname}
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
az vm run-command invoke -g ${rgname} -n ${vmlist[i]} --command-id RunShellScript --scripts 'echo "Port 2222" >> /etc/ssh/sshd_config' 'systemctl restart sshd;'; \
done
```

## Create a network security group and an an inbound security rule. 
```
export nsgname="NSG-K8S"
az network nsg create -g ${rgname} -n ${nsgname}
```
```
az network nsg rule create -g ${rgname} --nsg-name ${nsgname} -n Allow_SSH_2222 --priority 1000 \
    --destination-address-prefixes '*' --destination-port-ranges 2222 --access Allow \
    --protocol Tcp --description "Allow any IP to access port 2222."
```

## Associate the NSG with the virtual network/subnet.
```
vnetname=$(az network vnet list -g ${rgname} --query [].name -o tsv)
subnetname=$(az network vnet subnet list -g ${rgname} --vnet-name ${vnetname} --query [].name -o tsv)
az network vnet subnet update -g ${rgname} --vnet-name ${vnetname} -n ${subnetname} --network-security-grou
p ${nsgname}
```

## Set VMs' public IP to static and create a DNS name
```
export dnsname=($(az vm list -g ${rgname} --query [].name -o tsv | tr '[:upper:]' '[:lower:]'))
export vmpiplist=($(az network public-ip list -g ${rgname} --query [].name -o tsv))
for ((i=0; i<${#vmpiplist[@]}; i++)); do \
    for ((j=0; j<${#dnsname[@]}; j++)); do \
        az network public-ip update -g ${rgname} -n ${vmpiplist[i]} --dns-name ${dnsname[j]} --allocation-method static; \
    done \
done
```

## Install all K8s required components in all Azure VMs
```
export vmlist=($(az vm list -g ${rgname} --query [].name -o tsv))
for ((i=0; i<${#vmlist[@]}; i++)); do \
az vm run-command invoke -g ${rgname} -n ${vmlist[i]} --command-id RunShellScript --scripts 'curl -L https://raw.githubusercontent.com/msftjonw/CreateK8SFromScratch/main/installK8sRequiredComponents.sh -o ~/installK8sRequiredComponents.sh' 'sudo chmod +x ~/installK8sRequiredComponents.sh' 'sed -i -e 's/\r$//' ~/installK8sRequiredComponents.sh' '~/installK8sRequiredComponents.sh'; \
done
```

If the above command executing from the client machine does not work, SSH into each node and execute the command in the following order
```
ssh <dnsname>@k8smaster1.${location}.cloudapp.azure.com -p 2222
```
```
curl -L https://raw.githubusercontent.com/msftjonw/CreateK8SFromScratch/main/installK8sRequiredComponents.sh -o ~/installK8sRequiredComponents.sh
sudo chmod +x ~/installK8sRequiredComponents.sh
sed -i -e 's/\r$//' ~/installK8sRequiredComponents.sh
~/installK8sRequiredComponents.sh
```

## Initialize a K8s cluster from the master node
SSH into the master node.
```
ssh k8sadmin@k8smaster1.${location}.cloudapp.azure.com -p 2222
```
Download the initialize shell script and execute it.
```
curl -L https://raw.githubusercontent.com/msftjonw/CreateK8SFromScratch/main/initializeK8SMasterNode.sh -o ~/initializeK8SMasterNode.sh
sudo chmod +x installK8SMasterNode.sh
sed -i -e 's/\r$//' ~/installK8SMasterNode.sh
sudo ./installK8SMasterNode.sh
```
Install Weave CNI to have all pods communicate across node.
```
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```
Get the command to join worker nodes to the initialized cluster. If forget to copy, execute the command below to get a new token and command.
```
kubeadm token create --print-join-command
```
Exit from the master node. <br/>

## Join worker nodes to the initialized K8s cluster
Replace the 'kubeadm join ...' command with the one you get from the K8s master node.
```
export workerlist=("K8S-Worker1" "K8S-Worker2" "K8S-Worker3")
for ((i=0; i<${#workerlist[@]}; i++)); do \
az vm run-command invoke -g ${rgname} -n ${workerlist[i]} --command-id RunShellScript --scripts 'sudo kubeadm join 10.0.0.4:6443 --token 3mazx9.oq4tqxy0xcor18km \
        --discovery-token-ca-cert-hash sha256:b181b027e5c3d637dfe00fdad02b7417e0c0486de4093a18110fd5074045ce62'; \
done
```

## Label the worker nodes
SSH into the master node.
```
ssh k8sadmin@k8smaster1.${location}.cloudapp.azure.com -p 2222
```
```
sudo apt-get install -y jq
export workerlist=($(kubectl get nodes -o json | jq '.items[].metadata.name' | grep worker | tr -d '"'))
for ((i=0; i<${#workerlist[@]}; i++)); do \
kubectl label node ${workerlist[i]} node-role.kubernetes.io/worker=worker; \
done
```

---

## Since all Azure VMs will auto shutdown at 6PM PST. The script below will start all Azure VMs at once.
```
export rgname="RG-K8S"
export vmlist=($(az vm list -g ${rgname} --query [].name -o tsv))
for ((i=0; i<${#vmlist[@]}; i++)); do \
    echo "Powering on ${vmlist[i]}."; \
    az vm start -g ${rgname} -n ${vmlist[i]}; \
done
```
