# Salt states for cloud and resources

This repository contains Salt states for cloud and other resources.

## Layout / design

### Installation

- `install/debian.sh` — install salt-ssh on Debian machines

### Salt configuration

- `config/master` — master configuration needed to make salt-ssh work

### Roster

- `etc/salt/roster` — defines machines in the Kubernetes cluster

### Salt states

`srv/salt/*` — separate directory for each Salt state:

- **containerd** — install containerd Docker container runtime
- **hosts** — hand-written DNS for nodes using private AWS IP addresses
- **network** — basic tools for network debugging
- **ssh** — SSH keys so that machines are reachable from local development and each other
- **hostname** — set the machine hostname
- **kubeadm_base** — updated control-plane Kubernetes components. Avoids manual CA certificate generation in favor of the cert-manager Kubernetes service; avoids custom network configs for the Kubernetes Flannel service. Includes basic machine configs, Kubernetes binaries, Kubernetes configurations, and systemd services.
- **kubeadm_worker** — updated worker-node Kubernetes components. Includes Kubernetes binaries, basic machine configs, Kubernetes configs, and systemd services.

- **k8s** — basic setup for Kubernetes node machines, including Kubernetes binaries and basic machine parameters.  
  **Note:** Deprecated in favor of `kubeadm_base`, kept for legacy older clusters.

- **k8s_control_plane** — basic setup for the Kubernetes control plane, including TLS certificates, control-plane-specific configurations and systemd services, CoreDNS.  
  **Note:** Deprecated in favor of `kubeadm_base`, kept for legacy older clusters.

- **k8s_worker_node** — additional worker-specific setup: worker-specific Kubernetes binaries, configurations for worker components, systemd services, TLS certificates, and network configurations.  
  **Note:** Deprecated in favor of `kubeadm_worker`, kept for legacy older clusters.

- **ca_certs** — holds TLS certificates for machines.  
  **Note:** Deprecated in favor of Kubernetes cert-manager.

- **etcd** — state to install etcd on the control-plane node.  
  **Note:** Deprecated in favor of running etcd inside Kubernetes.

## Salt state conventions

- Do not commit tarballs or binaries to this repository. Use `archive.extract` to download instead.
  - Downloading binaries to S3 and using their HTTP endpoint is allowed as an optimization.

## Salt pillar conventions

To GPG-encrypt a secret:

```bash
echo "foobar" | gpg --homedir . --encrypt --armor --recipient "<username>"
```

## Salt-SSH setup

1. Generate a GPG key in your local Salt config directory — this lets you encrypt SSH keys before committing them to the Salt repo.
2. Encrypt SSH keys using GPG.
3. Place encrypted SSH keys into the pillar file.
4. When reading pillar keys, skip the filename path: use `pillar('aws_default_key')`, not `pillar('secrets:aws_default_key')`.
5. Salt will use the GPG key to decrypt before shipping to minions.

## Salt-SSH commands

- Shut down instances in a group:

  ```bash
  salt-ssh <ids> system.shutdown
  ```

- Highstate:

  ```bash
  salt-ssh <ids> state.highstate
  ```

- Apply a specific state:

  ```bash
  salt-ssh <ids> state.apply <state_name>
  ```

## containerd reference

`ctr` is the containerd CLI.

- List running containers:

  ```bash
  ctr tasks list
  ```

## Kubernetes reference

### Add a node to the cluster

1. On the control-plane node, generate a join token:

   ```bash
   kubeadm token create --print-join-command
   ```

2. On the worker node, join (example):

   ```bash
   kubeadm join 10.0.0.12:6443 --token <redacted> --discovery-token-ca-cert-hash <redacted>
   ```

3. Worker kubelet unit (reference):

   ```text
   ExecStart=/usr/local/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --cgroup-driver=systemd
   ```

### Remove a node from the cluster

```bash
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --force
kubectl delete node <node>
```
