#!/usr/bin/python3
import os
import sys
import yaml
import logging
import argparse
import subprocess

from logger import setup_logging, LOG_LEVELS

# TODO: store cluster configs in .json file or smth
DEFAULT_CLUSTER_NAME = "kubernetes-cluster-1"
DEFAULT_API_URL = "https://k8s-control-plane-1.kubernetes.local:6443"
DEFAULT_CERT_DIRECTORY = "/var/lib/kubernetes"

# TODO: generate configs for worker nodes
COMPONENTS = (
    "kube-proxy",
    "kube-controller-manager",
    "kube-scheduler",
    "admin",
    "kubelet",
)

LOGGER = logging.getLogger("GenerateKubeconfigs")


def log_command(cmd):
    cmd = [str(x) for x in cmd]

    LOGGER.info(f"Running command {' '.join(cmd)}")


def run_kubectl_config(output_dir, subcommand, key_name, config_file, **kwargs):
    """
    Run a 'kubectl config' command, usually of the format:

    kubectl config <subcommand> <key_name> **kwargs
    """
    cmd = [
        "kubectl",
        "config",
        subcommand,
        key_name,
    ]

    for k, v in kwargs.items():
        cmd.append(f"--{k}={v}")

    config_file = os.path.join(
        output_dir,
        config_file,
    )

    cmd.append(f"--kubeconfig={config_file}")

    log_command(cmd)

    return subprocess.check_output(cmd)


def get_cert_file(cert_directory, fname, embed_certs=False):
    """
    Get path to certificate file

    Kwargs:

    embed_certs                 : bool, if True then this function will raise on not finding file, otw it cannot embed b64 cert data
    """
    fname = os.path.join(
        cert_directory,
        fname,
    )

    if embed_certs and not os.path.exists(fname):
        raise Exception(
            f"Could not find certificate file {fname}; will not be able to embed data in resulting .kubeconfig file"
        )

    return fname


def generate_kubeconfig(
    output_dir, component, cluster_name, certs_dir, api_server_url, embed_certs=False
):
    config_file = f"{component}.kubeconfig"

    ca_cert_file = get_cert_file(certs_dir, "ca.crt", embed_certs=embed_certs)

    #### set-cluster ####
    cluster_args = {
        "certificate-authority": ca_cert_file,
        "server": api_server_url,
        "kubeconfig": config_file,
    }

    if embed_certs:
        cluster_args["embed-certs"] = "true"

    run_kubectl_config(
        output_dir,
        "set-cluster",
        cluster_name,
        config_file,
        **cluster_args,
    )

    #### set-credentials ####
    client_cert = get_cert_file(certs_dir, f"{component}.crt", embed_certs=embed_certs)
    client_key = get_cert_file(certs_dir, f"{component}.key", embed_certs=embed_certs)

    cred_args = {
        "client-certificate": client_cert,
        "client-key": client_key,
        "kubeconfig": config_file,
    }

    if embed_certs:
        cred_args["embed-certs"] = "true"

    run_kubectl_config(
        output_dir,
        "set-credentials",
        f"system:{component}",
        config_file,
        **cred_args,
    )

    #### set-context ####
    ctx_args = {
        "cluster": cluster_name,
        "user": f"system:{component}",
        "kubeconfig": config_file,
    }

    run_kubectl_config(
        output_dir,
        "set-context",
        "default",
        config_file,
        **ctx_args,
    )

    #### use-context ####
    use_args = {
        "kubeconfig": config_file,
    }

    run_kubectl_config(
        output_dir,
        "use-context",
        "default",
        config_file,
        **use_args,
    )


def create_parser():
    p = argparse.ArgumentParser()

    p.add_argument("--output-dir", "-o", required=True)
    p.add_argument("--cluster-name", "-N", default=DEFAULT_CLUSTER_NAME)
    p.add_argument(
        "--embed-certs",
        action="store_true",
        help="Embed cert data directly in kubeconfigs, not recommended to push these to git",
    )
    p.add_argument(
        "--cert-directory",
        "-C",
        help="Directory where .key and .crt files are stored",
        default=DEFAULT_CERT_DIRECTORY,
    )
    p.add_argument(
        "--api-server-url", "-A", default=DEFAULT_API_URL, help="URL of kube api server"
    )
    p.add_argument(
        "--components",
        "-c",
        nargs="+",
        default=COMPONENTS,
        help="Components to generate kubeconfigs for",
    )

    p.add_argument("--log-level", choices=LOG_LEVELS.keys(), default="INFO")

    return p


def main():
    p = create_parser()
    args = p.parse_args()
    setup_logging(args.log_level)

    if not os.path.exists(args.output_dir):
        LOGGER.info(f"Creating output directory {args.output_dir}")
        os.makedirs(args.output_dir, exist_ok=True)

    for component in args.components:
        generate_kubeconfig(
            args.output_dir,
            component,
            args.cluster_name,
            args.cert_directory,
            args.api_server_url,
            embed_certs=args.embed_certs,
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
