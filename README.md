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

## Create variables
```
export rgname="RG-K8S" #pick any name
export location="westus3" #pick any Azure location
export cni="Flannel" #pick any cni, weavenet, flannel, calico

export vnetname="VNet-${cni}"
export subnetname="Subnet-${cni}"
export nsgname="NSG-${cni}"

export elbpipname="PIP1-ELB-${cni}"
export elbname="ELB-${cni}"
export elbfename="ELBFE-${cni}"
export elbbpname="ELBBP-${cni}"

export mastervmname="Master1-${cni}"
export workervmname="Worker1-${cni}"
export adminusername="jonw"
export adminpassword="zaq1@WSXcde3"

```

## Create a resource group
```
az group create -l ${location} -n ${rgname}
```

## Create a virtual network and a subnet
```
az network vnet create -g ${rgname} -n ${vnetname} --address-prefixes 172.16.0.0/16 --subnet-name ${subnetname} --subnet-prefixes 172.16.1.0/24
```

## Create a standard public load balancer
```
az network lb create -g ${rgname} -n ELB-${cni} --sku Standard --backend-pool-name ${elbbpname} --frontend-ip-name ${elbfename} --public-ip-address ${elbpipname}
```

## Create servers
```
vmname=(${mastervmname} ${workervmname})
for vm in "${vmname[@]}"; do \
az vm create -g ${rgname} -n $vm --admin-username ${adminusername} \
--admin-password ${adminpassword} --image Canonical:UbuntuServer:18.04-LTS:latest \
--public-ip-address PIP1-$vm --public-ip-address-dns-name ${vm,,} --public-ip-address-allocation static --public-ip-sku Standard \
--vnet-name ${vnetname} --subnet ${subnetname} --nsg ""; \
done
```

## Associate servers to LB backend pool
```
vmname=($(az vm list -g ${rgname} --query [].name -o tsv))
for vm in "${vmname[@]}"; do \
az network nic ip-config address-pool add --address-pool ${elbbpname} \
--ip-config-name ipconfig$vm --nic-name $vmVMNic -g ${rgname} --lb-name ${elbname}; \
done
```


## Execute RunCommand in each Azure Linux VM to allow port 2222 for SSH
```
vmname=($(az vm list -g ${rgname} --query [].name -o tsv))
for vm in "${vmname[@]}"; do \
az vm run-command invoke -g ${rgname} -n $vm --command-id RunShellScript --scripts 'echo "Port 2222" >> /etc/ssh/sshd_config' 'systemctl restart sshd;'; \
done
```

## Create a network security group and an inbound security rule
```
az network nsg create -g ${rgname} -n ${nsgname}
```
```
az network nsg rule create -g ${rgname} --nsg-name ${nsgname} -n Allow_SSH_2222 --priority 1000 \
    --destination-address-prefixes '*' --destination-port-ranges 2222 --access Allow \
    --protocol Tcp --description "Allow any IP to access port 2222."
```

## Associate the NSG with the virtual network/subnet
```
az network vnet subnet update -g ${rgname} --vnet-name ${vnetname} -n ${subnetname} --network-security-group ${nsgname}
```

## Enable server auto shutdown
```
vmname=($(az vm list -g ${rgname} --query [].name -o tsv))
for vm in "${vmname[@]}"; do \
az vm auto-shutdown -g ${rgname} -n $vm --time 0200; \
done
```

## Install all K8s required components in all Azure VMs
```
vmname=($(az vm list -g ${rgname} --query [].name -o tsv))
for vm in "${vmname[@]}"; do \
az vm run-command invoke -g ${rgname} -n $vm --command-id RunShellScript --scripts 'sudo wget https://raw.githubusercontent.com/msftjonw/CreateK8SFromScratch/main/installK8sRequiredComponents.sh -P $HOME' 'sudo chmod +x $HOME/installK8sRequiredComponents.sh' 'sudo apt-get install dos2unix' 'sudo dos2unix $HOME/installK8sRequiredComponents.sh' 'sudo apt-get -y install at' 'sudo systemctl start atd && sudo systemctl enable atd' 'sudo $HOME/installK8sRequiredComponents.sh | at now +5 minutes' \
done
```
```
vmname=($(az vm list -g ${rgname} --query [].name -o tsv))
for vm in "${vmname[@]}"; do \
az vm run-command invoke -g ${rgname} -n $vm --command-id RunShellScript --scripts 'sudo $HOME/installK8sRequiredComponents.sh'; done
```

If the above command executing from the client machine does not work, SSH into each node and execute the command in the following order
```
ssh <dnsname>@k8smaster1.${location}.cloudapp.azure.com -p 2222
```
```
curl -L https://raw.githubusercontent.com/msftjonw/CreateK8SFromScratch/main/installK8sRequiredComponents.sh -o ~/installK8sRequiredComponents.sh
sudo chmod +x ~/installK8sRequiredComponents.sh
```
```
sed -i -e 's/\r$//' ~/installK8sRequiredComponents.sh
./installK8sRequiredComponents.sh
```

Check whether all required components are installed without issues.
SSH into each node and execute
```
cat /var/log/k8s_install_output.txt
```
```
cat /var/log/k8s_install_errors.txt
```

## Initialize a K8s cluster from the master node
SSH into the master node
```
ssh k8sadmin@${mastervmname}.${location}.cloudapp.azure.com -p 2222
```

Configure containerd and restart the service
```
sudo su
containerd config default>/etc/containerd/config.toml
exit
```

Initialize K8s cluster from the master node
```
sudo kubeadm init --config xxxx
```

Check whether K8S is initialized without issues.
```
cat /var/log/k8s_init_output.txt
```
```
cat /var/log/k8s_init_errors.txt
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

===

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
