/root/.ssh/authorized_keys:
    file.managed:
        - source: salt://ssh/authorized_keys
        - user: root
        - group: root
        - mode: 600

/root/.ssh/aws_default_keypair.pem:
    file.managed:
        - user: root
        - group: root
        - mode: 400
        - contents: |
            {{ pillar['aws_default_key'] | indent(12) }}

/root/.ssh/aws_default_keypair.pub:
    file.managed:
        - user: root
        - group: root
        - mode: 400
        - contents: |
            {{ pillar['aws_default_key_pub'] | indent(12) }}

/root/.ssh/config:
    file.managed:
        - user: root
        - group: root
        - mode: 600
        - source: salt://ssh/config
