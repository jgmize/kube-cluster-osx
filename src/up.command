#!/bin/bash

# up.command
#

#
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${DIR}"/functions.sh

# get App's Resources folder
res_folder=$(cat ~/kube-cluster/.env/resouces_path)

# path to the bin folder where we store our binary files
export PATH=${HOME}/kube-cluster/bin:$PATH

# check if iTerm.app exists
App="/Applications/iTerm.app"
if [ ! -d "$App" ]
then
    unzip "${res_folder}"/files/iTerm2.zip -d /Applications/
fi

# create logs dir
mkdir ~/kube-cluster/logs > /dev/null 2>&1

# copy bin files to ~/kube-cluster/bin
rsync -r --verbose --exclude 'helm' "${res_folder}"/bin/* ~/kube-cluster/bin/ > /dev/null 2>&1
rm -f ~/kube-cluster/bin/gen_kubeconfig
chmod 755 ~/kube-cluster/bin/*

# add ssh key to Keychain
if ! ssh-add -l | grep -q ssh/id_rsa; then
    ssh-add -K ~/.ssh/id_rsa &>/dev/null
fi
#

# check for password in Keychain
my_password=$(security 2>&1 >/dev/null find-generic-password -wa kube-cluster-app)
if [ "$my_password" = "security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain." ]
then
    echo " "
    echo "Saved password could not be found in the 'Keychain': "
    # save user password to Keychain
    save_password
fi

new_vm=0
# check if master's data disk exists, if not create it
if [ ! -f $HOME/kube-cluster/master-data.img ]; then
    echo " "
    echo "Data disks do not exist, they will be created now ..."
    create_data_disk
    new_vm=1
fi

# start cluster VMs
start_vms

# generate kubeconfig file
if [ ! -f $HOME/kube-cluster/kube/kubeconfig ]; then
    echo Generating kubeconfig file ...
    "${res_folder}"/bin/gen_kubeconfig $master_vm_ip
    echo " "
fi

# Set the environment variables
# set etcd endpoint
export ETCDCTL_PEERS=http://$master_vm_ip:2379
# wait till VM is ready
echo " "
echo "Waiting for k8smaster-01 to be ready..."
spin='-\|/'
i=1
until curl -o /dev/null http://$master_vm_ip:2379 >/dev/null 2>&1; do i=$(( (i+1) %4 )); printf "\r${spin:$i:1}"; sleep .1; done
echo " "
#

# set fleetctl endpoint
export FLEETCTL_TUNNEL=
export FLEETCTL_ENDPOINT=http://$master_vm_ip:2379
export FLEETCTL_DRIVER=etcd
export FLEETCTL_STRICT_HOST_KEY_CHECKING=false
#
sleep 3

#
echo "fleetctl list-machines:"
fleetctl list-machines
#
if [ $new_vm = 1 ]
then
    install_k8s_files
    #
    echo "  "
    deploy_fleet_units
fi

echo " "
# set kubernetes master
export KUBERNETES_MASTER=http://$master_vm_ip:8080
echo "Waiting for Kubernetes cluster to be ready. This can take a few minutes..."
spin='-\|/'
i=1
until curl -o /dev/null -sIf http://$master_vm_ip:8080 >/dev/null 2>&1; do i=$(( (i+1) %4 )); printf "\r${spin:$i:1}"; sleep .1; done
i=1
until ~/kube-cluster/bin/kubectl get nodes | grep $node1_vm_ip >/dev/null 2>&1; do i=$(( (i+1) %4 )); printf "\r${spin:$i:1}"; sleep .1; done
i=1
until ~/kube-cluster/bin/kubectl get nodes | grep $node2_vm_ip >/dev/null 2>&1; do i=$(( (i+1) %4 )); printf "\r${spin:$i:1}"; sleep .1; done
#
echo " "

if [ $new_vm = 1 ]
then
    # attach label to the nodes
    echo " "
    ~/kube-cluster/bin/kubectl label nodes $node1_vm_ip node=worker1
    ~/kube-cluster/bin/kubectl label nodes $node2_vm_ip node=worker2
    # copy add-ons files
    cp "${res_folder}"/k8s/*.yaml ~/kube-cluster/kubernetes
    install_k8s_add_ons "$master_vm_ip"
    #
fi
#
echo "kubernetes nodes list:"
~/kube-cluster/bin/kubectl get nodes
echo " "
#

cd ~/kube-cluster/kubernetes

# open bash shell
/bin/bash
