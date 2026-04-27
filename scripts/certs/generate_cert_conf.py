#!/usr/bin/python3
import os
import sys
import yaml
import logging
import argparse
import configparser

from logger import setup_logging, LOG_LEVELS

DEFAULT_PILLAR_DIR = "../../srv/salt/pillar/"
DEFAULT_HOSTNAME_PILLAR = os.path.join(DEFAULT_PILLAR_DIR, "hostnames.sls")

LOGGER = logging.getLogger("GenerateCertificateConf")


def generate_ca_conf(output_dir, dns_name):
    """
    Generate a CA configuration file for a given host
    """
    config = configparser.ConfigParser()

    config[dns_name] = {
        "distinguished_name": f"{dns_name}_distinguished_name",
        "prompt": "no",
        "req_extensions": f"{dns_name}_req_extensions",
    }

    config[f"{dns_name}_req_extensions"] = {
        "basicConstraints": "CA:FALSE",
        "extendedKeyUsage": "clientAuth, serverAuth",
        "keyUsage": "critical, digitalSignature, keyEncipherment",
        "nsCertType": "client",
        "nsComment": f"{dns_name} Certificate",
        "subjectAltName": f"DNS:{dns_name}, IP:127.0.0.1",
        "subjectKeyIdentifier": "hash",
    }

    config[f"{dns_name}_distinguished_name"] = {
        "CN": f"system:node:{dns_name}",
        "O": "system:nodes",
        "C": "US",
        "ST": "Illinois",
        "L": "Chicago",
    }

    config_file = os.path.join(
        output_dir,
        f"{dns_name}.ca.conf",
    )

    with open(config_file, "w") as out:
        LOGGER.info(f"Writing CA config file: {config_file}")
        config.write(out)


def dns_from_hostnames_pillar(filename):
    """
    Return a list of DNS names contained in the Salt hostnames pillar file
    """
    LOGGER.info(f"Obtaining DNS names from pillar file: {filename}")

    with open(filename, "r") as fh:
        data = yaml.safe_load(fh)

    hostnames = data["hostnames"]

    dns_names = []
    for _, details in hostnames.items():
        dns_name = details["hostname"]
        dns_names.append(dns_name)

    breakpoint()

    return dns_names


def create_parser():
    p = argparse.ArgumentParser()

    p.add_argument("--pillar-dir", "-p", default=DEFAULT_PILLAR_DIR)
    p.add_argument("--hostnames-file", "-H", default=DEFAULT_HOSTNAME_PILLAR)
    p.add_argument("--output-dir", "-o", required=True)

    p.add_argument("--log-level", choices=LOG_LEVELS.keys(), default="INFO")

    return p


def main():
    p = create_parser()
    args = p.parse_args()
    setup_logging(args.log_level)

    if not os.path.exists(args.output_dir):
        LOGGER.info(f"Creating output directory {args.output_dir}")
        os.makedirs(args.output_dir, exist_ok=True)

    dns_names = dns_from_hostnames_pillar(args.hostnames_file)

    for dns in dns_names:
        generate_ca_conf(args.output_dir, dns)

    return 0


if __name__ == "__main__":
    sys.exit(main())
