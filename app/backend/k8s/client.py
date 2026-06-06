from __future__ import annotations

from functools import lru_cache

from kubernetes import client, config
from kubernetes.config.config_exception import ConfigException


def _load_kubernetes_config() -> None:
    """Carga la configuración del cluster desde el pod o desde kubeconfig."""
    try:
        config.load_incluster_config()
    except ConfigException:
        config.load_kube_config()


@lru_cache(maxsize=1)
def get_api_client() -> client.ApiClient:
    """Crea un cliente API reutilizable con la configuración activa."""
    _load_kubernetes_config()
    return client.ApiClient()


def core_v1_api() -> client.CoreV1Api:
    return client.CoreV1Api(get_api_client())


def apps_v1_api() -> client.AppsV1Api:
    return client.AppsV1Api(get_api_client())
