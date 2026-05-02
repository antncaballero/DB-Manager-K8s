from __future__ import annotations

import json
from typing import Any

from models import DBType
from .utils import _run

def _resolve_db_type_from_chart(chart: str) -> DBType | None:
    """Resuelve tipo de DB gestionado por la app a partir del nombre del chart."""
    chart_lower = (chart or "").lower()
    if "mysql" in chart_lower:
        return DBType.MYSQL
    if "mongo" in chart_lower:
        return DBType.MONGO
    if "redis" in chart_lower:
        return DBType.REDIS
    if "cassandra" in chart_lower:
        return DBType.CASSANDRA
    return None

def _list_helm_releases(namespace: str | None = None) -> list[dict[str, Any]]:
    """Lista releases Helm en formato JSON."""
    cmd = ["helm", "list", "--output", "json"]
    if namespace:
        cmd += ["--namespace", namespace]
    else:
        cmd += ["--all-namespaces"]

    result = _run(cmd, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return []

    parsed = json.loads(result.stdout)
    if isinstance(parsed, list):
        return parsed
    if isinstance(parsed, dict):
        releases = parsed.get("Releases") or parsed.get("releases") or []
        if isinstance(releases, list):
            return releases
    return []

def _resolve_release(release_name: str, namespace: str) -> dict[str, Any]:
    """Resuelve y valida una release Helm gestionada por la aplicación."""
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

    return release

def helm_deploy(
    release_name: str,
    chart_path: str,
    values_file: str,
    namespace: str = "default",
) -> str:
    """Ejecuta `helm upgrade --install` con el values temporal."""
    cmd = [
        "helm", "upgrade", "--install",
        release_name,
        chart_path,
        "-f", values_file,
        "--namespace", namespace,
        "--create-namespace",
        "--wait",
        "--timeout", "5m",
    ]
    result = _run(cmd, timeout=330)
    return result.stdout

def helm_uninstall(release_name: str, namespace: str = "default") -> str:
    """Ejecuta `helm uninstall` para eliminar una release."""
    cmd = [
        "helm", "uninstall",
        release_name,
        "--namespace", namespace,
    ]
    result = _run(cmd)
    return result.stdout
