# This Git repository is a technical guide for creating a Kubernetes cluster with Azure VMs.

## Install Azure CLI in the local machine
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli#install

## Clone the GitHub repository on the local machine
```
git clone 
```

---

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
export cni="Flannel" #pick any cni, weavenet, flannel, calico
export location="westus3" #pick any Azure location

export rgname="RG-${cni}" #pick any name
export vnetname="VNet-${cni}"
export subnetname="Subnet-${cni}"
export nsgname="NSG-${cni}"

export elbpipname="PIP1-ELB-${cni}"
export elbname="ELB-${cni}"
export elbfename="ELBFE-${cni}"
export elbbpname="ELBBP-${cni}"

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

## Create master node(s)
### Change the number after "i<" to the desired amount of nodes. For example, if you will need 2 master nodes, change it to 2.
```
for ((i=1; i<=1; i++)); do \
export vmname=Master${i}-${cni}
az vm create -g ${rgname} -n ${vmname} --admin-username ${adminusername} --size Standard_D4S_v3 \
--admin-password ${adminpassword} --image Canonical:UbuntuServer:18.04-LTS:latest \
--public-ip-address PIP1-${vmname} --public-ip-address-dns-name ${vmname,,} --public-ip-address-allocation static --public-ip-sku Standard \
--vnet-name ${vnetname} --subnet ${subnetname} --nsg ""; \
done
```

## Create worker node(s)
### Change the number after "i<" to the desired amount of nodes. For example, if you will need 2 master nodes, change it to 2.
```
for ((i=1; i<=1; i++)); do \
export vmname=Worker${i}-${cni}
az vm create -g ${rgname} -n ${vmname} --admin-username ${adminusername} --size Standard_D4S_v3 \
--admin-password ${adminpassword} --image Canonical:UbuntuServer:18.04-LTS:latest \
--public-ip-address PIP1-${vmname} --public-ip-address-dns-name ${vmname,,} --public-ip-address-allocation static --public-ip-sku Standard \
--vnet-name ${vnetname} --subnet ${subnetname} --nsg ""; \
done
```

## Associate servers to LB backend pool
```
vmname=($(az vm list -g ${rgname} --query [].name -o tsv))
for vm in "${vmname[@]}"; do \
az network nic ip-config address-pool add --address-pool ${elbbpname} \
--ip-config-name ipconfig${vm} --nic-name ${vm}VMNic -g ${rgname} --lb-name ${elbname}; \
done
```


## Execute RunCommand in each Azure Linux VM to allow port 2222 for SSH
```
for vm in "${vmname[@]}"; do \
az vm run-command invoke -g ${rgname} -n ${vm} --command-id RunShellScript --scripts 'echo "Port 2222" >> /etc/ssh/sshd_config' 'systemctl restart sshd;'; \
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
for vm in "${vmname[@]}"; do \
az vm auto-shutdown -g ${rgname} -n ${vm} --time 0200; \
done
```

---

## Install all K8s required components in all Azure VMs
```
for vm in "${vmname[@]}"; do \
az vm run-command invoke -g ${rgname} -n ${vm} --command-id RunShellScript --scripts 'sudo wget https://raw.githubusercontent.com/msftjonw/K8sOnAzure/main/installK8sRequiredComponents.sh -P /home' 'sudo chmod +x /home/installK8sRequiredComponents.sh' 'sudo apt-get update && sudo apt-get install dos2unix && sudo dos2unix /home/installK8sRequiredComponents.sh' 'sudo systemctl start atd && sudo systemctl enable atd && sudo /home/installK8sRequiredComponents.sh | at now +5 minutes'; \
done
```

---

## Create an AAD service principal and grant it with Contributor permissions
### Note down the tenant ID, appId and password
```
subId=$(az account show --query "id" -o tsv)
az ad sp create-for-rbac -n SP-${cni} --role Contributor --scope /subscriptions/${subId}
```

## Initialize a K8s cluster from the master node
### SSH into the master node(s)

### Configure containerd and restart the service
```
sudo su
containerd config default > /etc/containerd/config.toml
systemctl restart containerd
exit
```

### Download cloud.conf to /etc/kubernetes
```
sudo wget -P /etc/kubernetes https://raw.githubusercontent.com/msftjonw/K8sOnAzure/main/cloud.conf
```

### Modify cloud.conf to use the newly created AAD service principal, Azure subscription and fill in all other required information.

### Download kubeadm.yaml to $HOME
```
wget -P $HOME https://raw.githubusercontent.com/msftjonw/K8sOnAzure/main/kubeadm.yaml
```
### Get kubeadm version (kubeadm version) and modify kubeadm.yaml file with it.

### Initialize the K8s cluster and note down the "kubeadm join" command.
```
sudo kubeadm init --config kubeadm.yaml
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Get the "kubeadm join" command again to join worker nodes to the initialized cluster. If forget to copy, execute the command below to get a new token and command.
```
kubeadm token create --print-join-command
```

## Different CNI solutions

### Weave CNI
```
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```
### Calico CNI <br/><br/>
https://projectcalico.docs.tigera.io/getting-started/kubernetes/self-managed-onprem/onpremises
Select "Manifest"
```
curl https://raw.githubusercontent.com/projectcalico/calico/v3.24.0/manifests/calico.yaml -O
```

#### If you are using pod CIDR 192.168.0.0/16, skip to the next step. If you are using a different pod CIDR with kubeadm, no changes are required - Calico will automatically detect the CIDR based on the running configuration. For other platforms, make sure you uncomment the CALICO_IPV4POOL_CIDR variable in the manifest and set it to the same value as your chosen pod CIDR.

#### Install Calico CNI
```
kubectl apply -f calico.yaml
```

### Flannel
#### Download the manifest file and modify the pod CIDR (search "net-conf.json") to be "10.11.0.0/16"
```
curl https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml -o $HOME/kube-flannel.yaml
```
```
kubectl apply -f $HOME/kube-flannel.yaml
```

---

## Join worker node(s) to the K8s cluster
### SSH into the worker node(s)

### Configure containerd and restart the service
```
sudo su
containerd config default > /etc/containerd/config.toml
systemctl restart containerd
exit
```

### Exit from the master node and SSH into the worker node(s) to execute the kubeadm join command.

---

## Label the worker nodes
### SSH into the master node(s)
```
sudo apt-get install -y jq
export workerlist=($(kubectl get nodes -o json | jq '.items[].metadata.name' | grep worker | tr -d '"'))
for ((i=0; i<${#workerlist[@]}; i++)); do \
kubectl label node ${workerlist[i]} node-role.kubernetes.io/worker=worker; \
done
```

---

## Start all Azure VMs at once
```
export rgname="xxxx" 
vmname=($(az vm list -g ${rgname} --query [].name -o tsv))
for vm in "${vmname[@]}"; do \
    echo "Powering on ${vm}."; \
    az vm start -g ${rgname} -n ${vm}; \
done
```

---

## Troubleshooting

### If the above command executing from the client machine does not work, SSH into each node and execute the command in the following order
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

### Check whether K8S is initialized without issues.
```
cat /var/log/k8s_init_output.txt
```
```
cat /var/log/k8s_init_errors.txt
```
