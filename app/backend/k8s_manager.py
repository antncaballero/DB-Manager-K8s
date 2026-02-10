"""
k8s_manager.py – Lógica pura de interacción con Kubernetes / Helm.

Funciones para:
  1. Generar el values.yaml temporal con las instancias de alumnos.
  2. Ejecutar `helm upgrade --install` / `helm uninstall`.
  3. Leer, actualizar y aplicar el ConfigMap `tcp-services` del Ingress NGINX.
  4. Ejecutar `kubectl apply` / `kubectl get`.

IMPORTANTE:  Se usa `subprocess` contra los binarios helm y kubectl que están
instalados dentro del contenedor Docker (ver Dockerfile).
"""

from __future__ import annotations

import json
import logging
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any

import yaml

from models import DB_CONFIG, DBType

# ── Logger ────────────────────────────────────────────────────────────────────
logger = logging.getLogger("k8s_manager")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")

# ── Constantes ────────────────────────────────────────────────────────────────
INGRESS_NAMESPACE = "ingress-nginx"
TCP_CONFIGMAP_NAME = "tcp-services"


# ═══════════════════════════════════════════════════════════════════════════════
#  1.  GENERACIÓN DEL VALUES TEMPORAL
# ═══════════════════════════════════════════════════════════════════════════════

def generate_instance_names(class_name: str, num_students: int) -> list[str]:
    """Genera los nombres de instancia para cada alumno.

    Formato: {class_name}-alumno{i}   (i empieza en 1).
    Ejemplo: bd-2025-turno1-alumno1, bd-2025-turno1-alumno2, ...
    """
    return [f"{class_name}-alumno{i}" for i in range(1, num_students + 1)]


def build_values_override(class_name: str, num_students: int) -> dict[str, Any]:
    """Construye el diccionario de values override para Helm.

    Devuelve algo como:
        instances:
          - name: bd-2025-turno1-alumno1
          - name: bd-2025-turno1-alumno2
    """
    names = generate_instance_names(class_name, num_students)
    return {"instances": [{"name": n} for n in names]}


def write_temp_values(values: dict[str, Any]) -> str:
    """Escribe el diccionario de values en un archivo temporal YAML.

    Devuelve la ruta absoluta del archivo creado.
    El llamante es responsable de eliminar el archivo cuando ya no lo necesite.
    """
    fd, path = tempfile.mkstemp(suffix=".yaml", prefix="helm-values-")
    try:
        with os.fdopen(fd, "w") as f:
            yaml.dump(values, f, default_flow_style=False)
        logger.info("Values temporal escrito en %s", path)
    except Exception:
        os.close(fd)
        raise
    return path


# ═══════════════════════════════════════════════════════════════════════════════
#  2.  COMANDOS HELM
# ═══════════════════════════════════════════════════════════════════════════════

def _run(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    """Wrapper de subprocess.run con logging y captura de salida."""
    logger.info("Ejecutando: %s", " ".join(cmd))
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.stdout:
        logger.info("STDOUT:\n%s", result.stdout.strip())
    if result.stderr:
        logger.warning("STDERR:\n%s", result.stderr.strip())
    if check and result.returncode != 0:
        raise RuntimeError(
            f"Comando falló (rc={result.returncode}): {' '.join(cmd)}\n"
            f"STDERR: {result.stderr.strip()}"
        )
    return result


def helm_deploy(
    release_name: str,
    chart_path: str,
    values_file: str,
    namespace: str = "default",
) -> str:
    """Ejecuta `helm upgrade --install` con el values temporal.

    Devuelve la salida estándar de Helm.
    """
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
    result = _run(cmd)
    return result.stdout


def helm_uninstall(release_name: str, namespace: str = "default") -> str:
    """Ejecuta `helm uninstall` para eliminar una release.

    Devuelve la salida estándar de Helm.
    """
    cmd = [
        "helm", "uninstall",
        release_name,
        "--namespace", namespace,
    ]
    result = _run(cmd)
    return result.stdout


# ═══════════════════════════════════════════════════════════════════════════════
#  3.  GESTIÓN DEL CONFIGMAP  tcp-services
# ═══════════════════════════════════════════════════════════════════════════════

def _get_tcp_configmap() -> dict[str, str]:
    """Lee el ConfigMap tcp-services y devuelve su campo `data` (dict).

    Si el ConfigMap existe pero no tiene data, devuelve {}.
    """
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
        with os.fdopen(fd, "w") as f:
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
    """Calcula los mapeos de puertos externos → servicios internos.

    Lee el ConfigMap actual para encontrar el primer bloque libre de
    puertos consecutivos dentro del rango permitido para el tipo de DB.

    Devuelve una lista de dicts:
        [
            {
                "student_name": "bd-2025-turno1-alumno1",
                "external_port": 3306,
                "internal_service": "default/bd-2025-turno1-alumno1:3306",
            },
            ...
        ]
    """
    config = DB_CONFIG[db_type]
    internal_port: int = config["internal_port"]
    port_start: int = config["port_range_start"]
    port_end: int = config["port_range_end"]

    # Puertos ya ocupados en el ConfigMap
    current_data = _get_tcp_configmap()
    occupied_ports = {int(p) for p in current_data.keys()}

    # Buscar bloque libre consecutivo de tamaño num_students
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
    db_type: DBType,
    class_name: str,
    num_students: int,
    namespace: str = "default",
) -> None:
    """Elimina del ConfigMap tcp-services las entradas correspondientes a una clase.

    Busca en el ConfigMap actual las entradas cuyo valor apunta a los servicios
    de esta clase y las elimina.
    """
    config = DB_CONFIG[db_type]
    internal_port: int = config["internal_port"]
    names = set(generate_instance_names(class_name, num_students))

    current_data = _get_tcp_configmap()
    if not current_data:
        logger.info("ConfigMap tcp-services está vacío, nada que limpiar.")
        return

    # Construir los valores esperados para identificar las entradas a borrar
    # Formato de valor: "namespace/nombre-servicio:puerto"
    expected_values = {f"{namespace}/{n}:{internal_port}" for n in names}

    cleaned_data = {
        port: svc
        for port, svc in current_data.items()
        if svc not in expected_values
    }

    removed = len(current_data) - len(cleaned_data)
    if removed > 0:
        _apply_tcp_configmap(cleaned_data)
        logger.info("ConfigMap tcp-services: eliminadas %d entradas.", removed)
    else:
        logger.info("ConfigMap tcp-services: no se encontraron entradas para limpiar.")


# ═══════════════════════════════════════════════════════════════════════════════
#  4.  ORQUESTACIÓN COMPLETA  (usadas por main.py)
# ═══════════════════════════════════════════════════════════════════════════════

def deploy_class(
    db_type: DBType,
    class_name: str,
    num_students: int,
    namespace: str = "default",
) -> list[dict[str, Any]]:
    """Orquesta el despliegue completo de una clase.

    1. Genera values override.
    2. Ejecuta helm upgrade --install.
    3. Calcula puertos y actualiza ConfigMap tcp-services.
    4. Limpia archivos temporales.

    Devuelve los mappings de puertos.
    """
    config = DB_CONFIG[db_type]
    chart_path: str = config["chart_path"]
    release_name = class_name

    # 1. Generar values
    values = build_values_override(class_name, num_students)
    values_file = write_temp_values(values)

    try:
        # 2. Helm deploy
        logger.info(
            "Desplegando release '%s' con chart '%s' (%d alumnos)...",
            release_name, chart_path, num_students,
        )
        helm_deploy(release_name, chart_path, values_file, namespace)

        # 3. Calcular puertos y actualizar ConfigMap
        mappings = calculate_port_mappings(db_type, class_name, num_students, namespace)
        update_tcp_configmap(mappings)

        logger.info("Despliegue de '%s' completado con éxito.", release_name)
        return mappings

    finally:
        # 4. Limpieza del values temporal
        Path(values_file).unlink(missing_ok=True)
        logger.info("Archivo temporal %s eliminado.", values_file)


def destroy_class(
    db_type: DBType,
    class_name: str,
    num_students: int,
    namespace: str = "default",
) -> None:
    """Orquesta la destrucción completa de una clase.

    1. Ejecuta helm uninstall.
    2. Limpia las entradas del ConfigMap tcp-services.
    """
    release_name = class_name

    # 1. Helm uninstall
    logger.info("Eliminando release '%s'...", release_name)
    helm_uninstall(release_name, namespace)

    # 2. Limpiar ConfigMap
    clean_tcp_configmap(db_type, class_name, num_students, namespace)

    logger.info("Release '%s' eliminada con éxito.", release_name)
