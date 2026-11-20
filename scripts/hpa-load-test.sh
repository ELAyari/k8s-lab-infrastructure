#!/usr/bin/env bash
# Install metrics-server, make HPA more sensitive, generate synthetic load.
set -euo pipefail

# Metrics server (needed for HPA CPU/memory metrics)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl rollout status deployment/metrics-server -n kube-system
kubectl top nodes

# Lower HPA thresholds so the demo scales quickly
kubectl patch hpa backend-hpa -n stylenest --type='json' -p='[
  {"op":"replace","path":"/spec/metrics/0/resource/target/averageUtilization","value":20},
  {"op":"replace","path":"/spec/metrics/1/resource/target/averageUtilization","value":20}
]'

# Clean previous load pods, then run 5 aggressive generators
kubectl delete pod load load2 load3 -n stylenest 2>/dev/null || true
for i in 1 2 3 4 5; do
  kubectl run load$i --image=busybox --restart=Never -n stylenest -- sh -c \
    "while true; do wget -q -O- http://backend.stylenest:4000/allproducts; \
     wget -q -O- http://backend.stylenest:4000/newcollections; \
     wget -q -O- http://backend.stylenest:4000/popularinwomen; done"
done

watch -n 10 kubectl get hpa -n stylenest
