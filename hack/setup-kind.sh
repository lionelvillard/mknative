#!/usr/bin/env bash

BASE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

cd $BASE_DIR

echo "starting kind cluster"
kind create cluster --name knative --config kind-config.yaml

echo "installing calico"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
