#!/usr/bin/python3
import os
import sys
import yaml
import logging
import argparse
import subprocess

from logger import LOG_LEVELS, setup_logging

DEFAULT_GPG_USER = None # redacted
DEEFAULT_GPG_HOMEDIR = "~/salt/gpgkeys"
DEFAULT_OPENSSL_BINARY = "/usr/local/ssl/bin/openssl"

LOGGER = logging.getLogger("SaltCertCreator")

COMPONENTS = (
    "admin",
    # "node-0",
    # "node-1",
    "kube-proxy",
    "kube-scheduler",
    "kube-controller-manager",
    "kube-api-server",
    "service-accounts",
    "k8s-worker-1",
)


def represent_multiline_str(dumper, data):
    """
    Custom representer for strings.
    If the string contains a newline, represent it as a literal block scalar.
    Otherwise, use the default string representation.
    """
    if "\n" in data:
        # Use style='|' for literal block scalar
        return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")
    return dumper.represent_scalar("tag:yaml.org,2002:str", data)


yaml.add_representer(str, represent_multiline_str)


def log_command(cmd):
    cmd = [str(x) for x in cmd]
    LOGGER.info(f"Running command: {' '.join(cmd)}")


def run_command_if_file_absent(cmd, filename, force=False):
    if os.path.exists(filename) and not force:
        LOGGER.info(
            f"Output filename {filename} already exists, not running command {' '.join(cmd)}"
        )
        return

    log_command(cmd)

    return subprocess.check_output(cmd)


def get_encrypted_text(filename, gpg_user, gpg_homedir=None, no_encrypt=False):
    if no_encrypt:
        with open(filename, "r") as out:
            return out.read()

    return gpg_encrypt(
        filename,
        gpg_user,
        gpg_homedir=gpg_homedir,
    )


def write_pillar_file(
    pillar_file, out_dict, mode="w", indent=4, write_encrypt_header=True
):
    LOGGER.info(f"Writing to pillar file {pillar_file} in mode: {mode}")
    with open(pillar_file, mode) as out:
        if write_encrypt_header:
            out.write("#!yaml|gpg\n")

        for k, v in out_dict.items():
            yaml.dump(
                {k: v},
                out,
                sort_keys=False,
                indent=indent,
            )
            out.write("\n")


def create_dir(output_dir):
    if not os.path.exists(output_dir):
        LOGGER.info(f"Creating dir: {output_dir}")
        os.makedirs(output_dir, exist_ok=True)


def get_kube_pillar(pillar_dir):
    return os.path.join(pillar_dir, "kube_certs.sls")


def get_ca_pillar_file(pillar_dir):
    return os.path.join(pillar_dir, "ca_certs.sls")


def setup_kube_pillar(pillar_dir, no_encrypt=False):
    create_dir(pillar_dir)
    o = os.path.join(pillar_dir, f"kube_certs.sls")
    with open(o, "w") as out:
        if not no_encrypt:
            out.write("#!yaml|gpg\n")


def gpg_encrypt(file_to_encrypt, gpg_user, gpg_homedir=None, tls_1=False):
    with open(file_to_encrypt, "r") as fh:
        data = fh.read()

    # we should only do this for TLS v1
    if tls_1:
        data = data.replace("\n", "\\n\\n")

    cmd = [
        "echo",
        f'"{data}"',
        "|",
        "gpg",
        "--encrypt",
        "--armor",
        "--recipient",
        gpg_user,
    ]

    if gpg_homedir is not None:
        cmd += [
            "--homedir",
            gpg_homedir,
        ]

    log_command(cmd)

    enc = subprocess.check_output(" ".join(cmd), shell=True).decode()

    return enc


def create_kube_certs(
    openssl_binary,
    component,
    config_file,
    output_dir,
    pillar_dir,
    ca_key_file,
    ca_cert_file,
    days,
    gpg_user,
    gpg_homedir=None,
    no_encrypt=False,
    force=False,
):
    out_dict = {}

    key_outfile = os.path.join(
        output_dir,
        f"{component}.key",
    )

    #### Generate the cert key ####
    cmd = [openssl_binary, "genrsa", "-out", key_outfile, "4096"]

    run_command_if_file_absent(cmd, key_outfile, force=force)

    key = get_encrypted_text(
        key_outfile,
        gpg_user,
        gpg_homedir=gpg_homedir,
        no_encrypt=no_encrypt,
    )

    out_dict[f"{component}_ca_key"] = key

    #### Generate the cert sign request ####
    req_outfile = os.path.join(
        output_dir,
        f"{component}.csr",
    )

    cmd = [
        openssl_binary,
        "req",
        "-new",
        "-key",
        key_outfile,
        "-sha256",
        "-section",
        component,
        "-config",
        config_file,
        "-out",
        req_outfile,
    ]

    run_command_if_file_absent(cmd, req_outfile, force=force)

    #### Generate the .crt file ####
    crt_outfile = os.path.join(
        output_dir,
        f"{component}.crt",
    )

    cmd = [
        openssl_binary,
        "x509",
        "-req",
        "-days",
        str(days),
        "-in",
        req_outfile,
        "-copy_extensions",
        "copyall",
        "-sha256",
        "-CA",
        ca_cert_file,
        "-CAkey",
        ca_key_file,
        "-CAcreateserial",
        "-out",
        crt_outfile,
    ]

    run_command_if_file_absent(cmd, crt_outfile, force=force)

    crt = get_encrypted_text(
        crt_outfile,
        gpg_user,
        gpg_homedir=gpg_homedir,
        no_encrypt=no_encrypt,
    )

    out_dict[f"{component}_ca_crt"] = crt

    #### Write the pillar file ####
    pillar_file = get_kube_pillar(pillar_dir)

    write_pillar_file(
        pillar_file,
        out_dict,
        mode="a",
        write_encrypt_header=False,  # should have already been written
    )


def create_ca_certs(
    openssl_binary,
    config_file,
    output_dir,
    pillar_dir,
    days,
    gpg_user,
    gpg_homedir=None,
    no_encrypt=False,
    force=False,
):
    out_dict = {}

    #### Generate the CA key ####
    key_outfile = os.path.join(
        output_dir,
        "ca.key",
    )

    cmd = [openssl_binary, "genrsa", "-out", key_outfile, "4096"]

    run_command_if_file_absent(
        cmd,
        key_outfile,
        force=force,
    )

    key = get_encrypted_text(
        key_outfile,
        gpg_user,
        gpg_homedir=gpg_homedir,
        no_encrypt=no_encrypt,
    )

    out_dict["ca_key"] = key

    #### Generate the CA sign request ####
    req_outfile = os.path.join(
        output_dir,
        "ca.crt",
    )

    cmd = [
        openssl_binary,
        "req",
        "-x509",
        "-new",
        "-sha512",
        "-noenc",
        "-key",
        key_outfile,
        "-days",
        str(days),
        "-config",
        config_file,
        "-out",
        req_outfile,
    ]

    run_command_if_file_absent(
        cmd,
        req_outfile,
        force=force,
    )

    req = get_encrypted_text(
        req_outfile,
        gpg_user,
        gpg_homedir=gpg_homedir,
        no_encrypt=no_encrypt,
    )

    out_dict["ca_crt"] = req

    #### Write the pillar file ####
    pillar_file = get_ca_pillar_file(pillar_dir)

    write_pillar_file(
        pillar_file,
        out_dict,
        write_encrypt_header=not no_encrypt,
    )


def create_parser():
    parent = argparse.ArgumentParser(add_help=False)

    parent.add_argument("--log-level", "-L", choices=LOG_LEVELS.keys(), default="INFO")
    parent.add_argument("--output-dir", "-o", required=True)
    parent.add_argument("--pillar-dir", "-p", required=True)
    parent.add_argument(
        "--openssl-binary",
        default=DEFAULT_OPENSSL_BINARY,
        help="openssl binary to use, must do this because out of date openssl certs will break in k8s cluster",
    )
    parent.add_argument(
        "--config-file",
        "-c",
        required=True,
        help="Configuration file used to generate CA certs",
    )
    parent.add_argument(
        "--gpg-user",
        "-u",
        default=DEFAULT_GPG_USER,
        help="recipient of gpg encrypted text",
    )
    parent.add_argument(
        "--gpg-homedir",
        "-H",
        default=DEEFAULT_GPG_HOMEDIR,
        help="dir where GPG keyring lives if not using default",
    )
    parent.add_argument(
        "--no-encrypt",
        action="store_true",
        help="Don't encrypt certs before writing them to pillar file",
    )
    parent.add_argument(
        "--force", action="store_true", help="Overwrite existing cert files"
    )
    parent.add_argument(
        "--days", type=int, default=3653, help="Number of days cert is valid for"
    )

    main_parser = argparse.ArgumentParser()
    subparsers = main_parser.add_subparsers(dest="command", help="Available commands")

    # parser for CA certs
    ca_parser = subparsers.add_parser("ca", help="Generate CA certs", parents=[parent])

    # parser for Kube certs
    kube_parser = subparsers.add_parser(
        "kube", help="Generate certs for Kube components", parents=[parent]
    )
    kube_parser.add_argument(
        "--components",
        "-C",
        nargs="+",
        default=COMPONENTS,
        help="k8s components to generate certs for",
    )
    kube_parser.add_argument("--ca-key-file", "-k", help="File where CA key is kept", required=True)
    kube_parser.add_argument("--ca-cert-file", "-r", help="File where CA crt is kepy", required=True)

    return main_parser


def main():
    p = create_parser()
    args = p.parse_args()
    setup_logging(args.log_level)

    create_dir(args.output_dir)
    create_dir(args.pillar_dir)

    if args.command == "ca":
        create_ca_certs(
            args.openssl_binary,
            args.config_file,
            args.output_dir,
            args.pillar_dir,
            args.days,
            args.gpg_user,
            gpg_homedir=args.gpg_homedir,
            no_encrypt=args.no_encrypt,
            force=args.force,
        )
    elif args.command == "kube":
        setup_kube_pillar(args.pillar_dir)

        for component in args.components:
            create_kube_certs(
                args.openssl_binary,
                component,
                args.config_file,
                args.output_dir,
                args.pillar_dir,
                args.ca_key_file,
                args.ca_cert_file,
                args.days,
                args.gpg_user,
                gpg_homedir=args.gpg_homedir,
                no_encrypt=args.no_encrypt,
                force=args.force,
            )

    else:
        raise RuntimeError(f"Invalid command: {args.command}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
