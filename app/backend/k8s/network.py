from __future__ import annotations

import json
import logging
import tempfile
from pathlib import Path
from typing import Any

import yaml

from models import DB_CONFIG, DBType
from .utils import _run, generate_instance_names

logger = logging.getLogger("k8s.network")

INGRESS_NAMESPACE = "ingress-nginx"
TCP_CONFIGMAP_NAME = "tcp-services"

def _get_tcp_configmap() -> dict[str, str]:
    """Lee el ConfigMap tcp-services y devuelve su campo `data` (dict)."""
    cmd = [
        "kubectl", "get", "configmap", TCP_CONFIGMAP_NAME,
        "-n", INGRESS_NAMESPACE,
        "-o", "json",
    ]
    result = _run(cmd, check=False)

    if result.returncode != 0:
        logger.warning("ConfigMap %s no encontrado, se creará uno nuevo.", TCP_CONFIGMAP_NAME)
        return {}

    cm = json.loads(result.stdout)
    return cm.get("data", {}) or {}

def _apply_tcp_configmap(data: dict[str, str]) -> None:
    """Aplica (crea o actualiza) el ConfigMap tcp-services con kubectl apply."""
    configmap = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": TCP_CONFIGMAP_NAME,
            "namespace": INGRESS_NAMESPACE,
        },
        "data": data,
    }

    fd, path = tempfile.mkstemp(suffix=".yaml", prefix="tcp-cm-")
    try:
        with open(fd, "w") as f:
            yaml.dump(configmap, f, default_flow_style=False)
        logger.info("ConfigMap temporal escrito en %s", path)
        _run(["kubectl", "apply", "-f", path])
    finally:
        Path(path).unlink(missing_ok=True)
        logger.info("Archivo temporal %s eliminado.", path)

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

    cmd = [
        "kubectl", "get", "svc", "ingress-nginx-controller",
        "-n", INGRESS_NAMESPACE,
        "-o", "json",
    ]
    result = _run(cmd, check=False)
    if result.returncode != 0:
        logger.warning("No se pudo obtener el Service ingress-nginx-controller para sincronizar puertos.")
        return

    svc = json.loads(result.stdout)
    current_ports: list[dict[str, Any]] = svc.get("spec", {}).get("ports", [])

    base_ports = [p for p in current_ports if not p.get("name", "").endswith("-tcp")]

    tcp_ports: list[dict[str, Any]] = []
    for ext_port_str in sorted(tcp_data.keys(), key=int):
        ext_port = int(ext_port_str)
        tcp_ports.append({
            "name": f"{ext_port}-tcp",
            "port": ext_port,
            "targetPort": ext_port,
            "protocol": "TCP",
        })

    all_ports = base_ports + tcp_ports

    patch = json.dumps({"spec": {"ports": all_ports}})
    patch_cmd = [
        "kubectl", "patch", "svc", "ingress-nginx-controller",
        "-n", INGRESS_NAMESPACE,
        "--type=merge",
        "-p", patch,
    ]
    _run(patch_cmd)
    logger.info("Service ingress-nginx-controller sincronizado: %d puertos base + %d puertos TCP.", len(base_ports), len(tcp_ports))

def get_ingress_external_ip() -> str:
    """Obtiene la IP externa del servicio ingress-nginx-controller."""
    cmd = [
        "kubectl", "get", "svc", "ingress-nginx-controller",
        "-n", INGRESS_NAMESPACE,
        "-o", "json",
    ]
    result = _run(cmd, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        logger.warning("No se pudo obtener el servicio ingress-nginx-controller.")
        return ""

    svc = json.loads(result.stdout)

    ingress_list = svc.get("status", {}).get("loadBalancer", {}).get("ingress", [])
    for entry in ingress_list:
        ip = entry.get("ip", "")
        if ip:
            return ip
        hostname = entry.get("hostname", "")
        if hostname:
            return hostname

    external_ips = svc.get("spec", {}).get("externalIPs", [])
    if external_ips:
        return external_ips[0]

    cluster_ip = svc.get("spec", {}).get("clusterIP", "")
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
