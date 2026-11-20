# Kubernetes Production Laboratory

A hands-on multi-node Kubernetes cluster used to explore control-plane internals, overlay networking, workload scheduling, self-healing and observability. Nodes are bootstrapped with **Ansible + kubeadm** on Ubuntu machines, and a small cloud-native demo stack (**StyleNest**) runs on top with Prometheus/Grafana monitoring and HPA load testing.

## Topology

| Node | Role | Address |
|------|------|---------|
| `master` | Control plane | `10.10.10.199` |
| `worker1` | Worker | `10.10.10.11` |
| `worker2` | Worker | `10.10.10.149` |

- Kubernetes **1.30** via `kubeadm`, pinned apt versions
- **containerd** container runtime with the CRI sandbox image pinned
- **Weave Net** CNI overlay with IPAM quorum checks
- Workloads exposed through `NodePort` services, with readiness/liveness probes and `HorizontalPodAutoscaler`
- Prometheus + Grafana + node-exporter `DaemonSet` for observability

## Repository layout

```
ansible-k8s/
  ansible.cfg
  site.yml                 # prepare -> init control plane -> join workers -> verify
  inventory/hosts.ini      # master / worker node addresses
  group_vars/all.yml       # versions, CIDR, CNI settings
  roles/
    common/                # swap, kernel modules, sysctl, packages, containerd
    master/                # kubeadm init, kubeconfig, CNI, join token
    worker/                # idempotent kubeadm join
manifests/
  stylenest-stack.yaml     # demo app: namespaces, Deployments, Services, HPAs
  stylenest-monitoring.yaml# Prometheus RBAC, config, Grafana, node-exporter
scripts/
  hpa-load-test.sh         # metrics-server + synthetic load generator
```

## Bootstrap the cluster

1. Edit `ansible-k8s/inventory/hosts.ini` with your own node IPs and SSH user/key.
2. Adjust versions/CNI in `ansible-k8s/group_vars/all.yml` if needed.
3. Run the playbook:

```bash
cd ansible-k8s
ansible-playbook -i inventory/hosts.ini site.yml
```

4. Verify from the control plane:

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide
```

## Deploy the demo stack

```bash
kubectl apply -f manifests/stylenest-stack.yaml
kubectl apply -f manifests/stylenest-monitoring.yaml
```

> **Note:** secrets in the manifests are placeholders (`CHANGE_ME`). Replace them before any real deployment.

## Experiments to try

- **Node failure:** power off `worker1`, watch pods reschedule onto the surviving worker, then restore it.
- **Self-healing:** delete a pod directly and observe the Deployment controller recreate it.
- **Autoscaling:** run `scripts/hpa-load-test.sh` from a node with `kubectl` access and watch `kubectl get hpa -n stylenest` react to synthetic CPU/memory load.
- **Overlay networking:** inspect Weave IPAM state while nodes join to see how address consensus is reached.
- **Probes:** kill a container process and watch liveness probes trigger restarts while readiness probes gate traffic.

## Observations that shaped the design

- Overlay encapsulation and MTU mismatches silently fragment pod traffic; overlay interfaces must be aligned with the physical NIC MTU.
- Aggressive liveness probe timings cause cascading restart storms under load, so thresholds need backoff tolerance.
- A dedicated control-plane node reduces compute density but keeps `etcd` quorum and API-server latency stable during worker failures.

## License

MIT
