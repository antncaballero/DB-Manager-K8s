from __future__ import annotations

import json
import logging
import subprocess
from typing import Any

from .utils import _run
from .helm import _resolve_db_type_from_chart, _list_helm_releases, _resolve_release

logger = logging.getLogger("k8s.workloads")

def _get_statefulsets_for_release(release_name: str, namespace: str) -> list[dict[str, Any]]:
    """Obtiene StatefulSets de una release."""
    sts_cmd = [
        "kubectl", "get", "statefulsets",
        "-n", namespace,
        "-l", f"app.kubernetes.io/instance={release_name}",
        "-o", "json",
    ]
    sts_result = _run(sts_cmd, check=False)
    items: list[dict[str, Any]] = []
    if sts_result.returncode == 0 and sts_result.stdout.strip():
        sts_data = json.loads(sts_result.stdout)
        items = sts_data.get("items", [])

    if items:
        return items

    sts_all_cmd = [
        "kubectl", "get", "statefulsets",
        "-n", namespace,
        "-o", "json",
    ]
    sts_all_result = _run(sts_all_cmd, check=False)
    if sts_all_result.returncode != 0 or not sts_all_result.stdout.strip():
        return []

    all_data = json.loads(sts_all_result.stdout)
    return [
        item for item in all_data.get("items", [])
        if item.get("metadata", {}).get("name", "").startswith(f"{release_name}-")
    ]

def list_active_statefulsets(namespace: str | None = None) -> list[dict[str, Any]]:
    """Lista StatefulSets activos (réplicas > 0) de releases gestionadas por la app."""
    releases = _list_helm_releases(namespace=namespace)
    active: list[dict[str, Any]] = []
    for rel in releases:
        release_name = rel.get("name", "")
        rel_namespace = rel.get("namespace", "default")
        db_type = _resolve_db_type_from_chart(rel.get("chart", ""))

        if not release_name or db_type is None:
            continue

        for item in _get_statefulsets_for_release(release_name, rel_namespace):
            metadata = item.get("metadata", {})
            spec = item.get("spec", {})
            status = item.get("status", {})

            desired = int(spec.get("replicas", 0) or 0)
            if desired <= 0:
                continue

            active.append({
                "name": metadata.get("name", ""),
                "namespace": metadata.get("namespace", rel_namespace),
                "release_name": release_name,
                "db_type": db_type.value,
                "desired_replicas": desired,
                "ready_replicas": int(status.get("readyReplicas", 0) or 0),
            })

    return active

def scale_statefulset(statefulset_name: str, namespace: str, replicas: int) -> None:
    """Escala un StatefulSet al número de réplicas indicado."""
    cmd = [
        "kubectl",
        "scale",
        "statefulset",
        statefulset_name,
        f"--replicas={replicas}",
        "-n",
        namespace,
    ]
    _run(cmd)

def wake_release(release_name: str, namespace: str, timeout_seconds: int = 90) -> None:
    """Despierta una release escalando a 1 todos sus StatefulSets y esperando rollout."""
    releases = _list_helm_releases(namespace=namespace)
    release = next(
        (
            rel for rel in releases
            if rel.get("name") == release_name and rel.get("namespace", "default") == namespace
        ),
        None,
    )
    if release is None:
        raise RuntimeError(f"No se encontró la release '{release_name}' en namespace '{namespace}'.")

    db_type = _resolve_db_type_from_chart(release.get("chart", ""))
    if db_type is None:
        raise RuntimeError(
            f"La release '{release_name}' no corresponde a un chart gestionado por la aplicación."
        )

    items = _get_statefulsets_for_release(release_name, namespace)
    if not items:
        raise RuntimeError(
            f"No se encontraron StatefulSets para la release '{release_name}' en namespace '{namespace}'."
        )

    statefulset_names: list[str] = []
    for item in items:
        statefulset_name = item.get("metadata", {}).get("name", "")
        if not statefulset_name:
            continue

        statefulset_names.append(statefulset_name)
        scale_statefulset(statefulset_name, namespace, replicas=1)

    if not statefulset_names:
        raise RuntimeError(
            f"No se pudieron resolver StatefulSets válidos para la release '{release_name}'."
        )

    for statefulset_name in statefulset_names:
        rollout_cmd = [
            "kubectl",
            "rollout",
            "status",
            f"statefulset/{statefulset_name}",
            "-n",
            namespace,
            f"--timeout={timeout_seconds}s",
        ]
        try:
            _run(rollout_cmd, timeout=timeout_seconds + 20)
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError(
                f"Timeout al esperar el arranque de {statefulset_name} en namespace {namespace}."
            ) from exc

def _statefulset_status(desired_replicas: int, ready_replicas: int) -> str:
    if desired_replicas <= 0:
        return "hibernating"
    if ready_replicas >= desired_replicas:
        return "active"
    return "starting"

def list_release_statefulsets(release_name: str, namespace: str) -> list[dict[str, Any]]:
    """Lista StatefulSets de una release con estado y posibilidad de wake."""
    _resolve_release(release_name, namespace)

    items = _get_statefulsets_for_release(release_name, namespace)
    statefulsets: list[dict[str, Any]] = []
    for item in items:
        metadata = item.get("metadata", {})
        spec = item.get("spec", {})
        status = item.get("status", {})

        name = metadata.get("name", "")
        if not name:
            continue

        desired_replicas = int(spec.get("replicas", 0) or 0)
        ready_replicas = int(status.get("readyReplicas", 0) or 0)
        sts_namespace = metadata.get("namespace", namespace)
        sts_status = _statefulset_status(desired_replicas, ready_replicas)

        statefulsets.append(
            {
                "name": name,
                "namespace": sts_namespace,
                "release_name": release_name,
                "desired_replicas": desired_replicas,
                "ready_replicas": ready_replicas,
                "status": sts_status,
                "can_wake": desired_replicas == 0,
            }
        )

    statefulsets.sort(key=lambda sts: sts["name"])
    return statefulsets

def wake_statefulset(
    release_name: str,
    statefulset_name: str,
    namespace: str,
    timeout_seconds: int = 90,
) -> bool:
    """Despierta un StatefulSet concreto de una release."""
    _resolve_release(release_name, namespace)

    items = _get_statefulsets_for_release(release_name, namespace)
    target = next(
        (
            item for item in items
            if item.get("metadata", {}).get("name", "") == statefulset_name
        ),
        None,
    )
    if target is None:
        raise RuntimeError(
            f"No se encontró el StatefulSet '{statefulset_name}' para la release '{release_name}' en namespace '{namespace}'."
        )

    target_namespace = target.get("metadata", {}).get("namespace", namespace)
    desired_replicas = int(target.get("spec", {}).get("replicas", 0) or 0)

    if desired_replicas > 0:
        return False

    scale_statefulset(statefulset_name, target_namespace, replicas=1)

    rollout_cmd = [
        "kubectl",
        "rollout",
        "status",
        f"statefulset/{statefulset_name}",
        "-n",
        target_namespace,
        f"--timeout={timeout_seconds}s",
    ]
    try:
        _run(rollout_cmd, timeout=timeout_seconds + 20)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(
            f"Timeout al esperar el arranque de {statefulset_name} en namespace {target_namespace}."
        ) from exc

    return True
