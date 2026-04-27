extract-containerd:
    archive.extracted:
        - source: https://github.com/containerd/containerd/releases/download/v2.1.4/containerd-2.1.4-linux-amd64.tar.gz
        - name: /usr/local
        - user: root
        - group: root
        - source_hash: 316d510a0428276d931023f72c09fdff1a6ba81d6cc36f31805fea6a3c88f515

/lib/systemd/system/containerd.service:
    file.managed:
        - source: salt://containerd/containerd.service
        - user: root
        - group: root
        - mode: 640

/etc/containerd/config.toml:
    file.managed:
        - source: salt://containerd/config.toml
        - user: root
        - group: root
        - mode: 644
        - makedirs: True

start_containerd_service:
    service.running:
        - name: containerd
        - enable: True

restart_containerd_on_config:
    cmd.run:
        - name: "systemctl restart containerd"
        - onchanges:
            - /etc/containerd/config.toml

restart_systemd:
    cmd.run:
        - name : "systemctl daemon-reload && systemctl enable --now containerd"
        - onchanges:
            - /lib/systemd/system/containerd.service

/usr/local/sbin/runc:
    file.managed:
        - source: https://github.com/opencontainers/runc/releases/download/v1.3.0/runc.amd64
        - user: root
        - group: root
        - mode: 755
        - source_hash: 028986516ab5646370edce981df2d8e8a8d12188deaf837142a02097000ae2f2
        - makedirs: True

extract-cni-plugins:
    archive.extracted:
        - source: https://github.com/containernetworking/plugins/releases/download/v1.7.1/cni-plugins-linux-amd64-v1.7.1.tgz
        - name: /opt/cni/bin
        - user: root
        - group: root
        - source_hash: 1a28a0506bfe5bcdc981caf1a49eeab7e72da8321f1119b7be85f22621013098
