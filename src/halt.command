#!/bin/bash

#  halt.command

#
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${DIR}"/functions.sh

# get App's Resources folder
res_folder=$(cat ~/kube-cluster/.env/resouces_path)

# path to the bin folder where we store our binary files
export PATH=${HOME}/kube-cluster/bin:$PATH

# get password for sudo
my_password=$(security find-generic-password -wa kube-cluster-app)
# reset sudo
sudo -k
# enable sudo
echo -e "$my_password\n" | sudo -Sv > /dev/null 2>&1

# send halt to VMs
sudo "${res_folder}"/bin/corectl halt k8snode-01
sleep 1
sudo "${res_folder}"/bin/corectl halt k8snode-02
sleep 1
sudo "${res_folder}"/bin/corectl halt k8smaster-01