extract_etcd:
    archive.extracted:
        - source: https://storage.googleapis.com/etcd/v3.5.22/etcd-v3.5.22-linux-amd64.tar.gz
        - name: /tmp
        - user: root
        - group: root
        - skip_verify: True

move_etcd:
    file.managed:
        - name: /usr/local/bin/etcd
        - source: /tmp/etcd-v3.5.22-linux-amd64/etcd
        - user: root
        - group: root
        - mode: 755

move_etcdctl:
    file.managed:
        - name: /usr/local/bin/etcdctl
        - source: /tmp/etcd-v3.5.22-linux-amd64/etcdctl
        - user: root
        - group: root
        - mode: 755

move_etcdutl:
    file.managed:
        - name: /usr/local/bin/etcdutl
        - source: /tmp/etcd-v3.5.22-linux-amd64/etcdutl
        - user: root
        - group: root
        - mode: 755

/lib/systemd/system/etcd.service:
    file.managed:
        - source: salt://etcd/lib/systemd/system/etcd.service
        - user: root
        - group: root
        - mode: 640

/etc/etcd:
    file.directory:
        - user: root
        - group: root
        - mode: 755

/etc/etcd/ca.crt:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - contents: |
            {{ pillar['ca_crt'] | indent(12) }}

/etc/etcd/kube-api-server.key:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - contents: |
            {{ pillar['kube-api-server_ca_key'] | indent(12) }}

/etc/etcd/kube-api-server.crt:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - contents: |
            {{ pillar['kube-api-server_ca_crt'] | indent(12) }}

/var/lib/etcd:
    file.directory:
        - user: root
        - group: root
        - mode: 700

start_etcd:
    service.running:
        - name: etcd
        - enable: True

sync_etcd:
    cmd.run:
        - name: "systemctl daemon-reload && systemctl restart etcd"
        - onchanges:
            - /lib/systemd/system/etcd.service
            - /etc/etcd/ca.crt
            - /etc/etcd/kube-api-server.key
            - /etc/etcd/kube-api-server.crt
