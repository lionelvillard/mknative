#!/usr/bin/env bash

BASE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

cd $BASE_DIR

echo "starting kind cluster"
kind create cluster --name knative --config kind-config-mt-kourier.yaml

echo "installing calico"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

echo "installing Knative Serving"
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.4.0/serving-crds.yaml
kubectl wait --for=condition=Established --all crd
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.4.0/serving-core.yaml
kubectl wait pod --timeout=10m --for=condition=Ready -l !job-name -n knative-serving


# Multiple Kourier instances will be installed...
#echo "installing Kourier"
#kubectl apply -f https://github.com/knative-sandbox/net-kourier/releases/download/knative-v1.4.0/kourier.yaml
#kubectl wait pod --timeout=10m --for=condition=Ready -l !job-name -n kourier-system
#kubectl wait pod --timeout=10m --for=condition=Ready -l !job-name -n knative-serving

# Tell Knative Serving to annotate services with the Kourier ingress class
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'

# use magic DNS
kubectl patch configmap -n knative-serving config-domain -p '{"data": {"127.0.0.1.sslip.io": ""}}'

