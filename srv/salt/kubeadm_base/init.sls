{%- set id = grains['id'] -%}
{%- set cluster_name = pillar['hostnames'][id]['cluster'] -%}

disable_swap:
    cmd.run:
        - name: swapoff -a

disable_swap_fstab:
    file.replace:
        - name: /etc/fstab
        - pattern: '^(\s*\S+\s+none\s+swap\s+.*)$'
        - repl: '# \1'
        - backup: True

/etc/sysctl.d/kubernetes.conf:
    file.managed:
        - source: salt://k8s/etc/sysctl.d/kubernetes.conf
        - user: root
        - group: root
        - mode: 644

restart_sysctl:
    cmd.run:
        - name: "sysctl restart --system"
        - onchanges:
            - /etc/sysctl.d/kubernetes.conf

load_overlay:
    kmod.present:
        - name: overlay

load_br_netfilter:
    kmod.present:
        - name: br_netfilter

/etc/modules-load.d/modules.conf:
    file.append:
        - text: |
            overlay
            br_netfilter
        - makedirs: True

/usr/local/bin/kubectl:
    file.managed:
        - source: https://dl.k8s.io/release/v1.33.4/bin/linux/amd64/kubectl
        - user: root
        - group: root
        - mode: 755
        - source_hash: c2ba72c115d524b72aaee9aab8df8b876e1596889d2f3f27d68405262ce86ca1

extract-cri:
    archive.extracted:
        - source: https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.31.0/crictl-v1.31.0-linux-amd64.tar.gz
        - name: /usr/local/bin
        - user: root
        - group: root
        - mode: 755
        - source_hash: 9daa32308090aedee5a7f2ab1f1428fef6f669a64e993f0b5b98db8ef6edd71b
        - enforce_toplevel: False

/usr/local/bin/kubeadm:
    file.managed:
        - source: https://dl.k8s.io/release/v1.33.4/bin/linux/amd64/kubeadm
        - user: root
        - group: root
        - mode: 755
        - source_hash: a109ebcb68e52d3dd605d92f92460c884dcc8b68aebe442404af19b6d9d778ec

/usr/local/bin/kubelet:
    file.managed:
        - source: https://dl.k8s.io/release/v1.33.4/bin/linux/amd64/kubelet
        - user: root
        - group: root
        - mode: 755
        - source_hash: 109bd2607b054a477ede31c55ae814eae8e75543126dc4cea40b04424d843489

/usr/local/bin/kube-proxy:
    file.managed:
        - source: https://dl.k8s.io/release/v1.33.4/bin/linux/amd64/kube-proxy
        - user: root
        - group: root
        - mode: 755
        - source_hash: 0949a1cac5d7a014767a068d0a637eba46b58d97c6a335a939a6a64bf02a230e

/usr/local/bin/kube-apiserver:
    file.managed:
        - source: https://dl.k8s.io/release/v1.33.4/bin/linux/amd64/kube-apiserver
        - user: root
        - group: root
        - mode: 755
        - source_hash: d4cf921f007c75a446fc66cd9e73cf245ec049459989a71e3ef2e346ddceed2e

/usr/local/bin/kube-controller-manager:
    file.managed:
        - source: https://dl.k8s.io/release/v1.33.4/bin/linux/amd64/kube-controller-manager
        - user: root
        - group: root
        - mode: 755
        - source_hash: 13d58af4feea90b014c5e931cccdbbeb90c6ba1d509172ff87f91f1fcec05a41

/usr/local/bin/kube-scheduler:
    file.managed:
        - source: https://dl.k8s.io/release/v1.33.4/bin/linux/amd64/kube-scheduler
        - user: root
        - group: root
        - mode: 755
        - source_hash: e9883a018508dc2e09a86dbd9bee100a5fbf5253b4db05f32d3f2f41c8e31cd4

/usr/local/bin/minikube:
    file.managed:
        - source: https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
        - user: root
        - group: root
        - mode: 755
        - source_hash: cddeab5ab86ab98e4900afac9d62384dae0941498dfbe712ae0c8868250bc3d7

/etc/kubernetes/manifests:
    file.directory:
        - user: root
        - group: root
        - mode: 700
        - makedirs: True

/var/lib/kubernetes:
    file.directory:
        - user: root
        - group: root
        - mode: 750

/var/lib/kubernetes/encryption-config.yaml:
    file.managed:
        - contents: |
            kind: EncryptionConfiguration
            apiVersion: apiserver.config.k8s.io/v1
            resources:
              - resources:
                  - secrets
                providers:
                  - aescbc:
                      keys:
                        - name: key1
                          secret: {{ pillar["kubernetes_encryption_key"] }}
                  - identity: {}
        - user: root
        - group: root
        - mode: 640


/lib/systemd/system/kubelet.service:
    file.managed:
        - source: salt://kubeadm_base/lib/systemd/system/kubelet.service
        - user: root
        - group: root
        - mode: 640

start_kubelet_service:
    service.running:
        - name: kubelet
        - enable: True

sync_kubelet:
    cmd.run:
        - name: "systemctl daemon-reload && systemctl restart kubelet"
        - onchanges:
            - /lib/systemd/system/kubelet.service

/etc/kubernetes/cluster_configs/{{ cluster_name }}.config.yaml:
    file.managed:
        - template: jinja
        - user: root
        - group: root
        - mode: 644
        - makedirs: True
        - source: salt://kubeadm_base/cluster_configs/{{ cluster_name }}.config.yaml

{% set kubeadm_sentinel = '/etc/kubernetes/.kubeadm_complete' %}
init_control_plane:
    cmd.run:
       - name: "kubeadm init --config /etc/kubernetes/cluster_configs/{{ cluster_name }}.config.yaml && touch {{ kubeadm_sentinel }}"
       - creates: {{ kubeadm_sentinel }}
       - unless: test -f {{ kubeadm_sentinel }}

{% set kubectl_sentinel = '/root/.kube/.kubectl_complete' %}
setup_kubectl_config:
    cmd.run:
        - name: "mkdir -p /root/.kube && cp /etc/kubernetes/admin.conf /root/.kube/config && touch {{ kubectl_sentinel }}"
        - creates: {{ kubectl_sentinel }}
        - unless: test -f {{ kubectl_sentinel }}

/etc/kubernetes/flannel/kube-flannel.yaml:
    file.managed:
        - template: jinja
        - user: root
        - group: root
        - mode: 644
        - makedirs: True
        - source: salt://kubeadm_base/flannel/kube-flannel.yaml
        - requires:
            - setup_kubectl_config

setup_flannel_config:
    cmd.run:
        - name: "kubectl apply -f /etc/kubernetes/flannel/kube-flannel.yaml"
        - onchanges:
            - /etc/kubernetes/flannel/kube-flannel.yaml

/etc/kubernetes/cert-manager/cert-manager.yaml:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - makedirs: True
        - source: salt://kubeadm_base/cert-manager/cert-manager.yaml
        - requires:
            - setup_kubectl_config

set_cert_manager:
    cmd.run:
        - name: "kubectl apply -f /etc/kubernetes/cert-manager/cert-manager.yaml"
        - onchanges:
            - /etc/kubernetes/cert-manager/cert-manager.yaml


{# SHIP WORKER NODE CONFIG TO BOX, HELPS US NOT RERUN LABEL COMMANDS #}

{% set worker_nodes = pillar['clusters'][cluster_name]['worker_nodes'] %}
/etc/kubernetes/worker_nodes.json:
    file.serialize:
        - serializer: json
        - dataset: {{ worker_nodes }}
        - mode: 644
        - user: root
        - group: root

{# SET LABELS FOR RELEVANT WORKER NODES #}

{% for node, spec in worker_nodes.items() %}
    {% for label_key, label_value in spec.get('labels', {}).items() %}

set_node_{{ node }}_label_{{ label_key }}_{{ label_value }}:
    cmd.run:
        - name: "kubectl label nodes {{ node }} {{ label_key }}={{ label_value }}"
        - onchanges:
            - /etc/kubernetes/worker_nodes.json

    {% endfor %}
{% endfor %}
