{%- set id = grains['id'] -%} 
{%- set cluster_name = pillar['hostnames'][id]['cluster'] -%} 

/etc/kubernetes/resolv.conf:
    file.managed:
        - template: jinja
        - user: root
        - group: root
        - mode: 644
        - source: salt://k8s_worker_node/etc/kubernetes/resolv.conf
        - makedirs: True

/var/run/kubernetes:
    file.directory:
        - user: root
        - group: root
        - mode: 750
        - makedirs: True

/var/lib/kube-proxy:
    file.directory:
        - user: root
        - group: root
        - mode: 750
        - makedirs: True

/var/lib/kubernetes/kube-proxy.kubeconfig:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - source: salt://k8s_worker_node/var/lib/kubernetes/kube-proxy.kubeconfig

/var/lib/kubernetes/kube-proxy.crt:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - contents: |
            {{ pillar['kube-proxy_ca_crt'] | indent(12) }}

/var/lib/kubernetes/kube-proxy.key:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - contents: |
            {{ pillar['kube-proxy_ca_key'] | indent(12) }}

/var/lib/kube-proxy/kube-proxy-config.yaml:
    file.managed:
        - template: jinja
        - renderer: yaml
        - user: root
        - group: root
        - mode: 644
        - source: salt://k8s_worker_node/var/lib/kube-proxy/kube-proxy-config.yaml

/lib/systemd/system/kube-proxy.service:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - source: salt://k8s_worker_node/lib/systemd/system/kube-proxy.service

start_kube-proxy_service:
    service.running:
        - name: kube-proxy
        - enable: True

sync_kube-proxy:
    cmd.run:
        - name: "systemctl daemon-reload && systemctl restart kube-proxy"
        - onchanges:
            - /lib/systemd/system/kube-proxy.service
            - /var/lib/kube-proxy/kube-proxy-config.yaml




/var/lib/kubernetes/kubelet.kubeconfig:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - source: salt://k8s_worker_node/var/lib/kubernetes/kubelet.kubeconfig

/var/lib/kubelet:
    file.directory:
        - user: root
        - group: root
        - mode: 750
        - makedirs: True

/var/lib/kubernetes/ca.crt:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - contents: |
            {{ pillar['ca_crt'] | indent(12) }}

/var/lib/kubernetes/kubelet.crt:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - contents: |
            {{ pillar['{0}_ca_crt'.format(grains['id'])] | indent(12) }}

/var/lib/kubernetes/kubelet.key:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - contents: |
            {{ pillar['{0}_ca_key'.format(grains['id'])] | indent(12) }}

/etc/kubernetes/kubelet-config.yaml:
    file.managed:
        - source: salt://k8s_worker_node/kubelet-config.yaml
        - user: root
        - group: root
        - mode: 600 
        - makedirs: True

/lib/systemd/system/kubelet.service:
    file.managed:
        - source: salt://k8s_worker_node/lib/systemd/system/kubelet.service
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
            - /etc/kubernetes/kubelet-config.yaml
            - /var/lib/kubernetes/kubelet.kubeconfig




/etc/cni/net.d/10-bridge.conf:
    file.managed:
        - template: jinja
        - renderer: json
        - source: salt://k8s_worker_node/etc/cni/net.d/10-bridge.conf.jinja
        - user: root
        - group: root
        - mode: 644
        - makedirs: True

/etc/cni/net.d/99-loopback.conf:
    file.managed:
        - source: salt://k8s_worker_node/etc/cni/net.d/99-loopback.conf
        - user: root
        - group: root
        - mode: 644
        - makedirs: True

restart_containerd:
    cmd.run:
        - name: "systemctl restart containerd"
        - onchanges:
            - /etc/cni/net.d/10-bridge.conf
            - /etc/cni/net.d/99-loopback.conf

{% set worker_nodes = pillar['clusters'][cluster_name]['worker_nodes'] %}
{% for node_id, details in worker_nodes.items() %}
{% if node_id != id %}
{% set pod_cidr = details['pod_subnet'] %}
add_route_{{ pod_cidr }}:
    cmd.run:
        - name: "ip route replace {{ pod_cidr }} via {{ pillar['hostnames'][node_id]['private_ip'] }}"
{% endif %}
{% endfor %}
