/usr/local/share/ca-certificates/ca.crt:
    file.managed:
        - user: root
        - group: root
        - mode: 644 
        - contents: |
            {{ pillar['ca_crt'] | indent(12) }}

update_ca_certs:
    cmd.run:
        - name: "update-ca-certificates"
        - onchanges:
            - /usr/local/share/ca-certificates/ca.crt
