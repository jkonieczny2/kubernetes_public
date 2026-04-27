install_net_tools:
    pkg.installed:
        - pkgs:
            - net-tools
            - socat
            - conntrack
            - ipset
            - kmod
            - ifupdown
