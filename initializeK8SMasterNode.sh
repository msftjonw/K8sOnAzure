#!/bin/sh

#Create the output and error files
printf "\nCreate the output and error files.\n"
sudo touch /var/log/k8s_init_output.txt && sudo touch /var/log/k8s_init_errors.txt
sudo chown $(id -u) /var/log/k8s_init_output.txt && sudo chown $(id -u) /var/log/k8s_init_errors.txt

#Initialize a K8s cluster
printf "\nInitialize the K8s cluster from the master node.\n" >> /var/log/k8s_init_output.txt
sudo kubeadm init >> /var/log/k8s_init_output.txt 2>> /var/log/k8s_init_errors.txt

#Ensure KUBECONFIG is pointed to the context
printf "\nEnsure KUBECONFIG is pointed to the context.\n" >> /var/log/k8s_init_output.txt
sudo cp /etc/kubernetes/admin.conf $HOME/ >> /var/log/k8s_init_output.txt 2>> /var/log/k8s_init_errors.txt
sudo chown $(id -u) $HOME/admin.conf >> /var/log/k8s_init_output.txt 2>> /var/log/k8s_init_errors.txt
cat << EOF | sudo tee ~/.bashrc
export KUBECONFIG=$HOME/admin.conf
EOF
source ~/.bashrc >> /var/log/k8s_init_output.txt 2>> /var/log/k8s_init_errors.txt

