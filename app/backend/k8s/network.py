from __future__ import annotations

import logging
from typing import Any

from kubernetes import client
from kubernetes.client.exceptions import ApiException

from models import DB_CONFIG, DBType
from .client import core_v1_api
from .utils import generate_instance_names

logger = logging.getLogger("k8s.network")

INGRESS_NAMESPACE = "ingress-nginx"
TCP_CONFIGMAP_NAME = "tcp-services"

def _get_tcp_configmap() -> dict[str, str]:
    """Lee el ConfigMap tcp-services y devuelve su campo `data` (dict)."""
    api = core_v1_api()
    try:
        config_map = api.read_namespaced_config_map(
            name=TCP_CONFIGMAP_NAME,
            namespace=INGRESS_NAMESPACE,
        )
    except ApiException as exc:
        if exc.status == 404:
            logger.warning("ConfigMap %s no encontrado, se creará uno nuevo.", TCP_CONFIGMAP_NAME)
            return {}
        raise RuntimeError(
            f"No se pudo leer el ConfigMap '{TCP_CONFIGMAP_NAME}' en namespace '{INGRESS_NAMESPACE}'."
        ) from exc

    return config_map.data or {}

def _apply_tcp_configmap(data: dict[str, str]) -> None:
    """Crea o actualiza el ConfigMap tcp-services mediante la API de Kubernetes."""
    api = core_v1_api()
    body = client.V1ConfigMap(
        metadata=client.V1ObjectMeta(
            name=TCP_CONFIGMAP_NAME,
            namespace=INGRESS_NAMESPACE,
        ),
        data=data,
    )

    try:
        api.patch_namespaced_config_map(
            name=TCP_CONFIGMAP_NAME,
            namespace=INGRESS_NAMESPACE,
            body=body,
        )
    except ApiException as exc:
        if exc.status != 404:
            raise RuntimeError(
                f"No se pudo actualizar el ConfigMap '{TCP_CONFIGMAP_NAME}' en namespace '{INGRESS_NAMESPACE}'."
            ) from exc
        try:
            api.create_namespaced_config_map(
                namespace=INGRESS_NAMESPACE,
                body=body,
            )
        except ApiException as create_exc:
            raise RuntimeError(
                f"No se pudo crear el ConfigMap '{TCP_CONFIGMAP_NAME}' en namespace '{INGRESS_NAMESPACE}'."
            ) from create_exc

def calculate_port_mappings(
    db_type: DBType,
    class_name: str,
    num_students: int,
    namespace: str = "default",
) -> list[dict[str, Any]]:
    """Calcula los mapeos de puertos externos → servicios internos."""
    config = DB_CONFIG[db_type]
    internal_port: int = config["internal_port"]
    port_start: int = config["port_range_start"]
    port_end: int = config["port_range_end"]

    current_data = _get_tcp_configmap()
    occupied_ports = {int(p) for p in current_data.keys()}

    names = generate_instance_names(class_name, num_students)
    mappings: list[dict[str, Any]] = []

    candidate = port_start
    for name in names:
        while candidate in occupied_ports:
            candidate += 1
            if candidate > port_end:
                raise RuntimeError(
                    f"No hay suficientes puertos libres en el rango "
                    f"{port_start}-{port_end} para {num_students} alumnos."
                )
        mappings.append({
            "student_name": name,
            "external_port": candidate,
            "internal_service": f"{namespace}/{name}:{internal_port}",
        })
        candidate += 1

    return mappings

def update_tcp_configmap(mappings: list[dict[str, Any]]) -> None:
    """Añade los mapeos calculados al ConfigMap tcp-services."""
    current_data = _get_tcp_configmap()

    for m in mappings:
        current_data[str(m["external_port"])] = m["internal_service"]

    _apply_tcp_configmap(current_data)
    logger.info("ConfigMap tcp-services actualizado con %d nuevas entradas.", len(mappings))

def clean_tcp_configmap(
    class_name: str,
    namespace: str = "default",
) -> None:
    """Elimina del ConfigMap tcp-services las entradas correspondientes a una clase."""
    current_data = _get_tcp_configmap()
    if not current_data:
        logger.info("ConfigMap tcp-services está vacío, nada que limpiar.")
        return

    release_prefix = f"{namespace}/{class_name}-"

    cleaned_data = {
        port: svc
        for port, svc in current_data.items()
        if not svc.startswith(release_prefix)
    }

    removed = len(current_data) - len(cleaned_data)
    if removed > 0:
        _apply_tcp_configmap(cleaned_data)
        logger.info("ConfigMap tcp-services: eliminadas %d entradas.", removed)
    else:
        logger.info("ConfigMap tcp-services: no se encontraron entradas para limpiar.")

def _sync_ingress_service_ports() -> None:
    """Sincroniza los puertos del Service ingress-nginx-controller con el ConfigMap."""
    tcp_data = _get_tcp_configmap()
    api = core_v1_api()
    try:
        svc = api.read_namespaced_service(
            name="ingress-nginx-controller",
            namespace=INGRESS_NAMESPACE,
        )
    except ApiException as exc:
        if exc.status == 404:
            logger.warning("No se pudo obtener el Service ingress-nginx-controller para sincronizar puertos.")
            return
        raise RuntimeError(
            "No se pudo obtener el Service ingress-nginx-controller para sincronizar puertos."
        ) from exc

    current_ports = svc.spec.ports or []
    base_ports = [p for p in current_ports if not (p.name or "").endswith("-tcp")]

    tcp_ports: list[client.V1ServicePort] = []
    for ext_port_str in sorted(tcp_data.keys(), key=int):
        ext_port = int(ext_port_str)
        tcp_ports.append(
            client.V1ServicePort(
                name=f"{ext_port}-tcp",
                port=ext_port,
                target_port=ext_port,
                protocol="TCP",
            )
        )

    all_ports = base_ports + tcp_ports

    patch_body = {
        "spec": {
            "ports": [
                api.api_client.sanitize_for_serialization(port)
                for port in all_ports
            ]
        }
    }
    try:
        api.patch_namespaced_service(
            name="ingress-nginx-controller",
            namespace=INGRESS_NAMESPACE,
            body=patch_body,
        )
    except ApiException as exc:
        raise RuntimeError(
            "No se pudieron sincronizar los puertos del Service ingress-nginx-controller."
        ) from exc
    logger.info("Service ingress-nginx-controller sincronizado: %d puertos base + %d puertos TCP.", len(base_ports), len(tcp_ports))

def get_ingress_external_ip() -> str:
    """Obtiene la IP externa del servicio ingress-nginx-controller."""
    api = core_v1_api()
    try:
        svc = api.read_namespaced_service(
            name="ingress-nginx-controller",
            namespace=INGRESS_NAMESPACE,
        )
    except ApiException as exc:
        if exc.status == 404:
            logger.warning("No se pudo obtener el servicio ingress-nginx-controller.")
            return ""
        raise RuntimeError(
            "No se pudo obtener el servicio ingress-nginx-controller."
        ) from exc

    ingress_list = (svc.status.load_balancer.ingress or []) if svc.status and svc.status.load_balancer else []
    for entry in ingress_list:
        ip = entry.ip or ""
        if ip:
            return ip
        hostname = entry.hostname or ""
        if hostname:
            return hostname

    external_ips = svc.spec.external_i_ps or [] if svc.spec else []
    if external_ips:
        return external_ips[0]

    cluster_ip = svc.spec.cluster_ip or "" if svc.spec else ""
    if cluster_ip:
        return cluster_ip

    return ""

def _get_port_mappings_for_release(
    release_name: str,
    namespace: str,
    tcp_data: dict[str, str],
) -> list[dict[str, Any]]:
    """Extrae del ConfigMap tcp-services los mapeos que pertenecen a una release."""
    prefix = f"{namespace}/{release_name}-"
    mappings: list[dict[str, Any]] = []

    for ext_port, svc_value in tcp_data.items():
        if svc_value.startswith(prefix):
            svc_part = svc_value.split("/", 1)[1]
            svc_name = svc_part.split(":", 1)[0]
            student_name = svc_name[len(release_name) + 1:]
            mappings.append({
                "student_name": student_name,
                "external_port": int(ext_port),
                "internal_service": svc_value,
            })

    mappings.sort(key=lambda m: m["external_port"])
    return mappings

def check_port_availability(db_type: DBType, num_students: int) -> None:
    """Verifica que hay suficientes puertos libres para el despliegue."""
    config = DB_CONFIG[db_type]
    port_start: int = config["port_range_start"]
    port_end: int = config["port_range_end"]

    current_data = _get_tcp_configmap()
    occupied_ports = {int(p) for p in current_data.keys()}

    available_ports = [p for p in range(port_start, port_end + 1) if p not in occupied_ports]
    if len(available_ports) < num_students:
        raise RuntimeError(
            f"No hay suficientes puertos libres en el rango {port_start}-{port_end} "
            f"para desplegar {num_students} alumnos. Solo quedan {len(available_ports)} puertos disponibles."
        )
