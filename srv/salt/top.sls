base:
    '*':
        - containerd
        - hosts
        - network
        - ssh
        - hostname

    'k8s-control-plane-1':
        - k8s
        - k8s_control_plane
        - etcd
        - ca_certs

    'k8s-worker-1':
        - k8s
        - k8s_worker_node
        - ca_certs

    'k8s-master-1':
        - kubeadm_base

    'k8s-worker-2':
        - kubeadm_worker

    'k8s-worker-3':
        - kubeadm_worker
