clusters:
    kubernetes-cluster-1:
        service_cluster_ip_range: 10.32.0.0/16
        pod_cidr: 10.200.0.0/16
        cluster_dns_nameserver: 10.32.97.224
        kubectl_config_file: admin.kubeconfig
        etcd_version: 3.5.22

        control_planes:
            k8s-control-plane-1:
                cluster: kubernetes-cluster-1

        worker_nodes:
            k8s-worker-1:
                cluster: kubernetes-cluster-1
                pod_subnet: 10.200.0.0/24

    kubernetes-cluster-2:
        service_cluster_ip_range: 10.33.0.0/16
        pod_cidr: 10.201.0.0/16
        {# TODO: this will need to be a load balancer if we ever do multi ctrl plane setup #}
        apiserver_host: 10.0.0.12
        apiserver_port: 6443

        {# TODO: these don't actually do anything since we accepted defaults from kubeadm #}
        {# however in future we may want to setup mutli-node etcd, then we'd need to complete these #}
        etcd_version: 3.5.22
        etcd_host: k8s-master-1
        etcd_port: 2379

        control_planes:
            k8s-control-plane-1:
                cluster: kubernetes-cluster-2

        worker_nodes:
            k8s-worker-2:
                cluster: kubernetes-cluster-2
                labels:
                    postgres-operator: enabled
            k8s-worker-3:
                cluster: kubernetes-cluster-2
                labels:
                    postgres-operator: enabled
