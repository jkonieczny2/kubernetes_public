set_hostname:
    cmd.run:
        - name: hostnamectl set-hostname {{ pillar['hostnames'][grains['id']]['hostname'] }}
        - unless: test "{{ pillar['hostnames'][grains['id']]['hostname'] }}" = "$(hostname)"
