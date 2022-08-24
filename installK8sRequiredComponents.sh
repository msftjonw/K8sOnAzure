#!/bin/bash

# Delete the previous command output and error files
sudo rm -rf /var/log/k8s_install_output.txt && sudo rm -rf /var/log/k8s_install_errors.txt

# Create the command output and error files
printf "\nCreate the output and error files.\n"
sudo touch /var/log/k8s_install_output.txt && sudo touch /var/log/k8s_install_errors.txt
sudo chown $(id -u) /var/log/k8s_install_output.txt && sudo chown $(id -u) /var/log/k8s_install_errors.txt


# Disable swap memory
printf "\nDisable swap memory on the local machine.\n" >> /var/log/k8s_install_output.txt
sudo swapoff -a && sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


# Enable Kernel Modules and Change Settings in sysctl
printf "\nEnable Kernel Modules and Change Settings in sysctl on the local machine.\n" >> /var/log/k8s_install_output.txt
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay && sudo modprobe br_netfilter >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

printf "\nApply sysctl params without reboot on the local machine.\n" >> /var/log/k8s_install_output.txt
sudo sysctl --system >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt

# Install containerd
printf "\nInstall containerd on the local machine.\n" >> /var/log/k8s_install_output.txt 
sudo apt-get -y update && sudo apt install -y gnupg2 software-properties-common >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
sudo apt update && sudo apt install containerd.io -y >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
sudo mkdir -p /etc/containerd >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
sudo containerd config default>/etc/containerd/config.toml && exit >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
sudo systemctl restart containerd && sudo systemctl enable containerd >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt

#Install kubeadm kubelet and kubectl
printf "\nInstall kubeadm, kubelet, kubectl and kubernetes-cni on the local machine.\n" >> /var/log/k8s_install_output.txt
sudo apt-get -y update && sudo apt-get install -y apt-transport-https ca-certificates curl >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
sudo apt-get -y update && sudo apt -y install vim git curl wget kubelet kubeadm kubectl kubernetes-cni && sudo apt-mark hold kubelet kubeadm kubectl >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt
sudo systemctl enable kubelet && sudo systemctl start kubelet >> /var/log/k8s_install_output.txt 2>> /var/log/k8s_install_errors.txt




