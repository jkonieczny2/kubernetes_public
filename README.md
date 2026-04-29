# Salt states for cloud and resources

> Salt formulas and pillar patterns for provisioning cloud infrastructure—primarily Debian hosts, Kubernetes (kubeadm), and SSH access via **salt-ssh**.

---

## Table of contents

- [Layout & design](#layout--design) — install paths, roster, Salt modules  
- [Conventions](#conventions) — state rules, pillars, GPG secrets  
- [Salt-SSH](#salt-ssh) — one-time setup and routine commands  
- [References](#references) — containerd CLI and Kubernetes add/remove node  

---

## Layout & design

### Repository paths

Install, master config, and roster live outside `srv/salt`:

| Location | Purpose |
|---------|---------|
| [`install/debian.sh`](install/debian.sh) | Install **salt-ssh** on Debian machines |
| [`config/master`](config/master) | Master configuration required for salt-ssh |
| [`etc/salt/roster`](etc/salt/roster) | Inventories machines for the Kubernetes cluster |

States live under **`srv/salt/*`** — one directory per Salt state/module.

---

### Salt state modules

#### Active / current stack

| Module | Purpose |
|--------|---------|
| **containerd** | Install the containerd container runtime |
| **hosts** | Hand-written DNS for nodes (private AWS IPs) |
| **network** | Basic network debugging tools |
| **ssh** | SSH keys so hosts are reachable from dev machines and each other |
| **hostname** | Set the machine hostname |
| **kubeadm_base** | Modern control-plane: Kubernetes binaries/configs/services, cert-manager instead of manual CA wiring, avoids custom networking in favor of Flannel as deployed in-cluster |
| **kubeadm_worker** | Modern workers: binaries, configs, and systemd units aligned with kubeadm |

#### Legacy modules (keep for older clusters)

| Module | Purpose | Superseded by |
|--------|---------|---------------|
| **k8s** | Bootstrap Kubernetes node binaries/parameters | **`kubeadm_base`** |
| **k8s_control_plane** | Control plane TLS, CoreDNS, control-plane systemd units | **`kubeadm_base`** |
| **k8s_worker_node** | Worker binaries, certs, systemd, network snippets | **`kubeadm_worker`** |
| **ca_certs** | TLS material checked into Salt | **`cert-manager`** in Kubernetes |
| **etcd** | Install etcd on the control-plane OS | etcd **inside the cluster** (typical kubeadm/stack) |

---

## Conventions

### Salt states

| Do | Detail |
|----|--------|
| **Prefer downloads** | Do **not** commit tarballs or binaries. Use **`archive.extract`** (or similar) to fetch artifacts at apply time |
| **S3 shortcut** | Optional: upload binaries to S3 and point at their HTTP URLs (optimization only) |

### Salt pillar (GPG secrets)

Encrypt a string for use in pillars:

```bash
echo "foobar" | gpg --homedir . --encrypt --armor --recipient "<username>"
```

| Tip | Explanation |
|-----|---------------|
| GPG directory | Generate/import keys **in your local Salt config** so SSH secrets can be encrypted before commit |
| Encrypted keys | Place ciphertext in the pillar as usual; Salt decrypts with your GPG key before sending to minions |
| Pillar key path | Use `pillar('aws_default_key')` — **not** `pillar('secrets:aws_default_key')` when the file path is skipped |

---

## Salt-SSH

### Setup (once)

| Step | Action |
|------|--------|
| 1 | Generate a GPG key in your local Salt config directory |
| 2 | Encrypt SSH private keys with GPG |
| 3 | Store ciphertext in the appropriate pillar |
| 4 | Reference pillars without the `secrets:` filename prefix when applicable (see table above) |

Salt decrypts pillar material with your GPG key before shipping state to targets.

### Common commands

| Goal | Command |
|------|---------|
| Power off grouped hosts | `salt-ssh <ids> system.shutdown` |
| Full convergence | `salt-ssh <ids> state.highstate` |
| One state/module | `salt-ssh <ids> state.apply <state_name>` |

---

## References

### containerd (`ctr`)

| Task | Example |
|------|---------|
| List running containers / tasks | `ctr tasks list` |

### Kubernetes

#### Add a worker to the cluster

| Step | Node | Command / detail |
|------|------|------------------|
| 1 | Control plane | `kubeadm token create --print-join-command` |
| 2 | Worker | Paste the printed `kubeadm join …` (token + `--discovery-token-ca-cert-hash` from step 1) |
| 3 | Worker kubelet unit | Typical `ExecStart`: `/usr/local/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --cgroup-driver=systemd` |

Example join (placeholder values):

```bash
kubeadm join 10.0.0.12:6443 --token <redacted> --discovery-token-ca-cert-hash <redacted>
```

#### Remove a node cleanly

Run on the control plane:

```bash
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --force
kubectl delete node <node>
```
