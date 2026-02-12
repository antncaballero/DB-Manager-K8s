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
#  4.  SINCRONIZACIÓN DE PUERTOS DEL SERVICE INGRESS
# ═══════════════════════════════════════════════════════════════════════════════

def _sync_ingress_service_ports() -> None:
    """Sincroniza los puertos del Service ingress-nginx-controller con el ConfigMap.

    Aunque el controller de NGINX recarga automáticamente su configuración
    cuando el ConfigMap tcp-services cambia, el **Service** de Kubernetes
    no lo hace.  Si el Service no expone un puerto, el tráfico nunca llega
    al pod del controller.

    Esta función:
      1. Lee los puertos TCP definidos en el ConfigMap.
      2. Obtiene los puertos actuales del Service.
      3. Conserva los puertos base (http/https) y reemplaza los dinámicos.
      4. Aplica un JSON merge-patch sobre el Service.
    """
    tcp_data = _get_tcp_configmap()

    # ── Obtener el Service actual ─────────────────────────────────────
    cmd = [
        "kubectl", "get", "svc", "ingress-nginx-controller",
        "-n", INGRESS_NAMESPACE,
        "-o", "json",
    ]
    result = _run(cmd, check=False)
    if result.returncode != 0:
        logger.warning(
            "No se pudo obtener el Service ingress-nginx-controller "
            "para sincronizar puertos."
        )
        return

    svc = json.loads(result.stdout)
    current_ports: list[dict[str, Any]] = svc.get("spec", {}).get("ports", [])

    # ── Separar puertos base de los TCP dinámicos ─────────────────────
    # Los puertos TCP gestionados por nosotros se nombran "{puerto}-tcp".
    base_ports = [p for p in current_ports if not p.get("name", "").endswith("-tcp")]

    # ── Construir nuevos puertos TCP desde el ConfigMap ───────────────
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

    # ── Aplicar JSON merge-patch (reemplaza solo spec.ports) ──────────
    patch = json.dumps({"spec": {"ports": all_ports}})
    patch_cmd = [
        "kubectl", "patch", "svc", "ingress-nginx-controller",
        "-n", INGRESS_NAMESPACE,
        "--type=merge",
        "-p", patch,
    ]
    _run(patch_cmd)
    logger.info(
        "Service ingress-nginx-controller sincronizado: "
        "%d puertos base + %d puertos TCP.",
        len(base_ports), len(tcp_ports),
    )


# ═══════════════════════════════════════════════════════════════════════════════
#  5.  ORQUESTACIÓN COMPLETA  (usadas por main.py)
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

        # 4. Sincronizar puertos del Service del Ingress
        _sync_ingress_service_ports()

        logger.info("Despliegue de '%s' completado con éxito.", release_name)
        return mappings

    finally:
        # 4. Limpieza del values temporal
        Path(values_file).unlink(missing_ok=True)
        logger.info("Archivo temporal %s eliminado.", values_file)


def get_ingress_external_ip() -> str:
    """Obtiene la IP externa del servicio ingress-nginx-controller.

    Busca el campo status.loadBalancer.ingress[0].ip del Service de tipo
    LoadBalancer.  Si no lo encuentra, intenta con el campo externalIPs
    o devuelve cadena vacía.
    """
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

    # 1. status.loadBalancer.ingress[].ip
    ingress_list = svc.get("status", {}).get("loadBalancer", {}).get("ingress", [])
    for entry in ingress_list:
        ip = entry.get("ip", "")
        if ip:
            return ip
        # Algunos proveedores devuelven hostname en vez de ip
        hostname = entry.get("hostname", "")
        if hostname:
            return hostname

    # 2. spec.externalIPs
    external_ips = svc.get("spec", {}).get("externalIPs", [])
    if external_ips:
        return external_ips[0]

    # 3. spec.clusterIP como último recurso
    cluster_ip = svc.get("spec", {}).get("clusterIP", "")
    if cluster_ip:
        return cluster_ip

    return ""


def _get_port_mappings_for_release(
    release_name: str,
    namespace: str,
    tcp_data: dict[str, str],
) -> list[dict[str, Any]]:
    """Extrae del ConfigMap tcp-services los mapeos que pertenecen a una release.

    Busca entradas cuyo valor siga el patrón:
        {namespace}/{release_name}-alumnoN:{port}
    y las devuelve como lista de dicts.
    """
    prefix = f"{namespace}/{release_name}-"
    mappings: list[dict[str, Any]] = []

    for ext_port, svc_value in tcp_data.items():
        # svc_value ejemplo: "default/test-mysql-1-alumno1:3306"
        if svc_value.startswith(prefix):
            # Extraer el nombre del alumno del valor
            svc_part = svc_value.split("/", 1)[1]   # "test-mysql-1-alumno1:3306"
            svc_name = svc_part.split(":", 1)[0]      # "test-mysql-1-alumno1"
            # Nombre legible: parte después del release_name-
            student_name = svc_name[len(release_name) + 1:]  # "alumno1"
            mappings.append({
                "student_name": student_name,
                "external_port": int(ext_port),
                "internal_service": svc_value,
            })

    # Ordenar por puerto para consistencia
    mappings.sort(key=lambda m: m["external_port"])
    return mappings


def list_deployments(namespace: str | None = None) -> list[dict[str, Any]]:
    """Lista las releases de Helm desplegadas y obtiene info básica de StatefulSets.

    Devuelve una lista de dicts con información resumida de cada despliegue,
    incluyendo la IP externa del ingress y los puertos asignados.
    """
    # 0. Obtener IP externa del ingress y ConfigMap tcp-services (una sola vez)
    external_ip = get_ingress_external_ip()
    tcp_data = _get_tcp_configmap()

    # 1. Listar releases de Helm
    cmd = ["helm", "list", "--output", "json"]
    if namespace:
        cmd += ["--namespace", namespace]
    else:
        cmd += ["--all-namespaces"]

    result = _run(cmd, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return []

    releases = json.loads(result.stdout)
    deployments: list[dict[str, Any]] = []

    for rel in releases:
        release_name = rel.get("name", "")
        rel_namespace = rel.get("namespace", "default")
        chart = rel.get("chart", "")
        status = rel.get("status", "unknown")
        updated = rel.get("updated", "")

        # Detectar tipo de DB según el chart
        db_type_str = ""
        if "mysql" in chart.lower():
            db_type_str = "mysql"
        elif "mongo" in chart.lower():
            db_type_str = "mongo"
        else:
            continue  # No es un despliegue gestionado por esta app

        # 2. Obtener StatefulSets asociados
        #    Intentamos primero por label estándar; si no hay resultados,
        #    buscamos por prefijo de nombre (charts sin labels Helm).
        sts_cmd = [
            "kubectl", "get", "statefulsets",
            "-n", rel_namespace,
            "-l", f"app.kubernetes.io/instance={release_name}",
            "-o", "json",
        ]
        sts_result = _run(sts_cmd, check=False)
        items: list[dict[str, Any]] = []
        if sts_result.returncode == 0 and sts_result.stdout.strip():
            sts_data = json.loads(sts_result.stdout)
            items = sts_data.get("items", [])

        # Fallback: si no se encontraron por label, buscar por prefijo de nombre
        if not items:
            sts_all_cmd = [
                "kubectl", "get", "statefulsets",
                "-n", rel_namespace,
                "-o", "json",
            ]
            sts_all_result = _run(sts_all_cmd, check=False)
            if sts_all_result.returncode == 0 and sts_all_result.stdout.strip():
                all_data = json.loads(sts_all_result.stdout)
                items = [
                    item for item in all_data.get("items", [])
                    if item.get("metadata", {}).get("name", "").startswith(f"{release_name}-")
                ]

        sts_count = len(items)
        ready_count = 0
        for item in items:
            sts_status = item.get("status", {})
            ready = sts_status.get("readyReplicas", 0)
            ready_count += ready

        # 3. Obtener mapeos de puertos para esta release
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

    # 3. Sincronizar puertos del Service del Ingress
    _sync_ingress_service_ports()

    logger.info("Release '%s' eliminada con éxito.", release_name)
