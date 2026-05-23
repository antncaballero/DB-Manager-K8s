from __future__ import annotations

import logging
import threading
from pathlib import Path
from typing import Any

from models import DB_CONFIG, DBType

from .utils import build_values_override, write_temp_values
from .helm import (
    helm_deploy,
    helm_uninstall,
    _list_helm_releases,
    _resolve_db_type_from_chart,
    find_release_by_name,
)
from .network import (
    calculate_port_mappings,
    update_tcp_configmap,
    clean_tcp_configmap,
    _sync_ingress_service_ports,
    get_ingress_external_ip,
    _get_tcp_configmap,
    _get_port_mappings_for_release,
    check_port_availability,
)
from .workloads import (
    list_active_statefulsets,
    wake_release,
    list_release_statefulsets,
    wake_statefulset,
    _get_statefulsets_for_release,
)

logger = logging.getLogger("k8s")

k8s_network_lock = threading.Lock()
class_name_lock = threading.Lock()
_inflight_class_names: set[str] = set()

class ClassNameConflictError(RuntimeError):
    """Error cuando el nombre de clase ya existe en el cluster."""

def _ensure_unique_class_name(class_name: str) -> None:
    existing = find_release_by_name(class_name)
    if existing:
        namespace = existing.get("namespace", "default")
        raise ClassNameConflictError(
            f"La clase '{class_name}' ya existe en namespace '{namespace}'."
        )

def deploy_class(
    db_type: DBType,
    class_name: str,
    num_students: int,
    namespace: str = "default",
) -> list[dict[str, Any]]:
    """Orquesta el despliegue completo de una clase."""
    config = DB_CONFIG[db_type]
    chart_path: str = config["chart_path"]
    release_name = class_name

    inflight_added = False
    with class_name_lock:
        if class_name in _inflight_class_names:
            raise ClassNameConflictError(
                f"La clase '{class_name}' ya se esta desplegando."
            )
        _ensure_unique_class_name(class_name)
        _inflight_class_names.add(class_name)
        inflight_added = True

    values = build_values_override(class_name, num_students)
    values_file: str | None = None

    try:
        values_file = write_temp_values(values)
        logger.info(
            "Desplegando release '%s' con chart '%s' (%d alumnos)...",
            release_name, chart_path, num_students,
        )
        check_port_availability(db_type, num_students)
        
        helm_deploy(release_name, chart_path, values_file, namespace)

        wake_release(release_name, namespace, timeout_seconds=300)

        with k8s_network_lock:
            # 1. Calculamos los puertos (asegurándonos de que nadie más los use)
            mappings = calculate_port_mappings(db_type, class_name, num_students, namespace)
            # 2. Guardamos en el ConfigMap
            update_tcp_configmap(mappings)
            # 3. Sincronizamos el Service para abrir la "puerta" pública
            _sync_ingress_service_ports()

        logger.info("Despliegue de '%s' completado con éxito.", release_name)
        return mappings

    finally:
        if values_file:
            Path(values_file).unlink(missing_ok=True)
            logger.info("Archivo temporal %s eliminado.", values_file)
        if inflight_added:
            with class_name_lock:
                _inflight_class_names.discard(class_name)

def list_deployments(namespace: str | None = None) -> list[dict[str, Any]]:
    """Lista las releases de Helm desplegadas y obtiene info básica de StatefulSets."""
    external_ip = get_ingress_external_ip()
    tcp_data = _get_tcp_configmap()

    releases = _list_helm_releases(namespace=namespace)
    deployments: list[dict[str, Any]] = []

    for rel in releases:
        release_name = rel.get("name", "")
        rel_namespace = rel.get("namespace", "default")
        chart = rel.get("chart", "")
        helm_status = rel.get("status", "unknown")
        updated = rel.get("updated", "")

        db_type = _resolve_db_type_from_chart(chart)
        if db_type is None:
            continue

        db_type_str = db_type.value
        items = _get_statefulsets_for_release(release_name, rel_namespace)

        sts_count = len(items)
        ready_count = 0
        desired_count = 0
        for item in items:
            sts_spec = item.get("spec", {})
            sts_status = item.get("status", {})
            desired = sts_spec.get("replicas", 0)
            ready = sts_status.get("readyReplicas", 0)
            desired_count += int(desired or 0)
            ready_count += ready

        if items:
            if desired_count == 0:
                status = "hibernating"
            elif desired_count == ready_count:
                status = "active"
            else:
                status = "starting"
        else:
            status = helm_status

        port_mappings = _get_port_mappings_for_release(
            release_name, rel_namespace, tcp_data,
        )

        deployments.append({
            "release_name": release_name,
            "namespace": rel_namespace,
            "db_type": db_type_str,
            "chart": chart,
            "status": status,
            "updated": updated,
            "statefulsets": sts_count,
            "ready_instances": ready_count,
            "external_ip": external_ip,
            "port_mappings": port_mappings,
        })

    return deployments

def destroy_class(
    class_name: str,
    namespace: str = "default",
) -> None:
    """Orquesta la destrucción completa de una clase."""
    release_name = class_name
    logger.info("Eliminando release '%s'...", release_name)
    helm_uninstall(release_name, namespace)
    clean_tcp_configmap(class_name, namespace)
    _sync_ingress_service_ports()
    logger.info("Release '%s' eliminada con éxito.", release_name)

def list_wake_releases(namespace: str | None = None) -> list[dict[str, Any]]:
    """Lista releases gestionadas por la app para selector de wakeup."""
    deployments = list_deployments(namespace=namespace)
    releases = [
        {
            "release_name": d["release_name"],
            "namespace": d["namespace"],
            "db_type": d["db_type"],
            "status": d["status"],
            "statefulsets": d["statefulsets"],
        }
        for d in deployments
    ]
    releases.sort(key=lambda rel: (rel["namespace"], rel["release_name"]))
    return releases

__all__ = [
    "helm_deploy",
    "helm_uninstall",
    "list_active_statefulsets",
    "list_wake_releases",
    "list_release_statefulsets",
    "wake_statefulset",
    "wake_release",
    "deploy_class",
    "destroy_class",
    "list_deployments",
    "ClassNameConflictError",
]
