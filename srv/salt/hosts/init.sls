/etc/hosts:
    file.managed:
        - user: root
        - group: root
        - mode: 644
        - contents: |
            # The following lines are desirable for IPv6 capable hosts
            ::1 ip6-localhost ip6-loopback
            fe00::0 ip6-localnet
            ff00::0 ip6-mcastprefix
            ff02::1 ip6-allnodes
            ff02::2 ip6-allrouters
            ff02::3 ip6-allhosts

            {% for id, details in pillar.hostnames.items() %}
            {{ details['private_ip'] }}    {{ details['hostname'] }}
            {{ details['private_ip'] }}    {{ details['hostname'] }}.kubernetes.local
            {%- endfor %}


