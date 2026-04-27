{%- set id = grains['id'] -%}
{%- set cluster_name = pillar['hostnames'][id]['cluster'] -%}

/etc/kubernetes/config:
    file.directory:
        - user: root
        - group: root
        - mode: 750
        - makedirs: True

{% for item in ['key', 'crt'] %}
/var/lib/kubernetes/ca.{{item}}:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - makedirs: True
        - contents: |
            {{ pillar['ca_{0}'.format(item)] | indent(12) }}
{% endfor %}

{% set kube_certs = ['kube-api-server', 'kube-scheduler', 'kube-controller-manager', 'service-accounts'] %}
{% for kc in kube_certs %}
{% for item in ['key', 'crt'] %}
/var/lib/kubernetes/{{kc}}.{{item}}:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - makedirs: True
        - contents: |
            {{ pillar['{0}_ca_{1}'.format(kc, item)] | indent(12) }}
{% endfor %}
{% endfor %}

{% set kubeconfigs = ['kube-controller-manager', 'kube-scheduler'] %}
{% for kc in kubeconfigs %}
/var/lib/kubernetes/{{kc}}.kubeconfig:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - source: salt://k8s_control_plane/var/lib/kubernetes/{{kc}}.kubeconfig
{% endfor %}

{% set kube_yaml = ['kube-scheduler'] %}
{% for ky in kube_yaml %}
/etc/kubernetes/config/{{ky}}.yaml:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - source: salt://k8s_control_plane/etc/kubernetes/config/{{ky}}.yaml
        - makedirs: True
{% endfor %}

{% set components = ['kube-apiserver', 'kube-controller-manager', 'kube-scheduler'] %}
{% for component in components %}
/lib/systemd/system/{{component}}.service:
    file.managed:
        - template: jinja
        - user: root
        - group: root
        - mode: 644
        - source: salt://k8s_control_plane/lib/systemd/system/{{component}}.service

start_{{component}}:
    service.running:
        - name: {{component}}
        - enable: True
        - watch:
            - file: /lib/systemd/system/{{component}}.service
            {% if component in kubeconfigs %}
            - file: /var/lib/kubernetes/{{component}}.kubeconfig
            {% endif %}
            {% if component in kube_yaml %}
            - file: /etc/kubernetes/config/{{component}}.yaml
            {% endif %}
            - file: /var/lib/kubernetes/*.crt

sync_{{component}}:
    cmd.run:
        - name: "systemctl daemon-reload && systemctl restart {{component}}"
        - onchanges:
            - /lib/systemd/system/{{component}}.service
            {% if component in kube_yaml %}
            - /etc/kubernetes/config/{{component}}.yaml
            {% endif %}

{% endfor %}

/root/kubernetes-cluster-1/admin.kubeconfig:
    file.managed:
        - user: root
        - group: root
        - mode: 600
        - source: salt://k8s_control_plane/root/kubernetes-cluster-1/admin.kubeconfig
        - makedirs: True

/etc/kubernetes/config/kube-apiserver-to-kubelet.yaml:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - source: salt://k8s_control_plane/etc/kubernetes/config/kube-apiserver-to-kubelet.yaml
        - require:
            - service: kube-apiserver

apply_rbac:
    cmd.run:
        - name: "kubectl apply -f /etc/kubernetes/config/kube-apiserver-to-kubelet.yaml --kubeconfig /root/kubernetes-cluster-1/admin.kubeconfig"
        - onchanges:
            - /etc/kubernetes/config/kube-apiserver-to-kubelet.yaml
            - /root/kubernetes-cluster-1/admin.kubeconfig

{% set worker_nodes = pillar['clusters'][cluster_name]['worker_nodes'] %}
{% for node_id, details in worker_nodes.items() %}
{% set pod_cidr = details['pod_subnet'] %}
add_route_{{ pod_cidr }}:
    cmd.run:
        - name: "ip route replace {{ pod_cidr }} via {{ pillar['hostnames'][node_id]['private_ip'] }}"
{% endfor %}

/etc/kubernetes/config/coredns.yaml:
    file.managed:
        - template: jinja
        - user: root
        - group: root
        - mode: 644
        - source: salt://k8s_control_plane/etc/kubernetes/config/coredns.yaml
        - require:
            - service: kube-apiserver
            - service: kube-controller-manager

apply_coredns:
    cmd.run:
        - name: "kubectl apply -f /etc/kubernetes/config/coredns.yaml"
        - onchanges:
            - /etc/kubernetes/config/coredns.yaml 
