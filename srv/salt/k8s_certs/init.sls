/var/lib/kubelet:
    file.directory:
        - user: root
        - group: root
        - mode: 750
        - makedirs: True

/var/lib/kubelet/ca.crt:
    file.managed:
        - contents: {{ pillar["ca_crt"] | indent(12) }}
        - user: root
        - group: root
        - mode: 640
