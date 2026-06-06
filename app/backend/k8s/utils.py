from __future__ import annotations

import logging
import os
import subprocess
import tempfile
from typing import Any

import yaml

logger = logging.getLogger("k8s.utils")

DEFAULT_STORAGE_CLASS_NAME = "db-manager-default"

def generate_instance_names(class_name: str, num_students: int) -> list[str]:
    """Genera los nombres de instancia para cada alumno."""
    return [f"{class_name}-alumno{i}" for i in range(1, num_students + 1)]

def build_values_override(class_name: str, num_students: int) -> dict[str, Any]:
    """Construye el diccionario de values override para Helm."""
    names = generate_instance_names(class_name, num_students)
    storage_class_name = os.getenv("DB_MANAGER_STORAGE_CLASS", DEFAULT_STORAGE_CLASS_NAME).strip()
    values: dict[str, Any] = {"instances": [{"name": n} for n in names]}
    if storage_class_name:
        values["storage"] = {"className": storage_class_name}
    return values

def write_temp_values(values: dict[str, Any]) -> str:
    """Escribe el diccionario de values en un archivo temporal YAML."""
    fd, path = tempfile.mkstemp(suffix=".yaml", prefix="helm-values-")
    try:
        with os.fdopen(fd, "w") as f:
            yaml.dump(values, f, default_flow_style=False)
        logger.info("Values temporal escrito en %s", path)
    except Exception:
        os.close(fd)
        raise
    return path

def _run(cmd: list[str], *, check: bool = True, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    """Wrapper de subprocess.run con logging y captura de salida."""
    logger.info("Ejecutando: %s", " ".join(cmd))
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if result.stdout:
        #logger.info("STDOUT:\n%s", result.stdout.strip())
        logger.info("Comando ejecutado con éxito (rc=%d)", result.returncode)
    if result.stderr:
        logger.warning("STDERR:\n%s", result.stderr.strip())
    if check and result.returncode != 0:
        raise RuntimeError(
            f"Comando falló (rc={result.returncode}): {' '.join(cmd)}\n"
            f"STDERR: {result.stderr.strip()}"
        )
    return result
