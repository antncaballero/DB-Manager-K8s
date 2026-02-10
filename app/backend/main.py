"""
main.py – API REST del TFG DB Manager.

Endpoints:
  POST   /deploy   → Despliega un cluster de BBDDs para una clase.
  DELETE  /destroy  → Elimina el cluster y limpia la configuración de red.
  GET    /health    → Healthcheck básico.
"""

from __future__ import annotations

import logging

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from models import (
    DBType,
    DeployRequest,
    DeployResponse,
    DestroyRequest,
    DestroyResponse,
    PortMapping,
)
import k8s_manager

# ── Logger ────────────────────────────────────────────────────────────────────
logger = logging.getLogger("main")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

# ── Aplicación FastAPI ────────────────────────────────────────────────────────
app = FastAPI(
    title="TFG DB Manager – Backend API",
    description=(
        "API para desplegar y destruir clusters de bases de datos "
        "(MySQL / MongoDB) en Kubernetes mediante Helm."
    ),
    version="0.1.0",
)

# CORS – permitir que el frontend (local) acceda a la API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],      # En producción, restringir al dominio del frontend
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ═══════════════════════════════════════════════════════════════════════════════
#  ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════════

@app.get("/health")
def health_check() -> dict[str, str]:
    """Healthcheck simple para Docker / K8s liveness probes."""
    return {"status": "ok"}


@app.post("/deploy", response_model=DeployResponse)
def deploy(req: DeployRequest) -> DeployResponse:
    """Despliega un cluster de bases de datos para una clase.

    Flujo:
      1. Genera values.yaml temporal con las instancias de alumnos.
      2. Ejecuta `helm upgrade --install`.
      3. Calcula los puertos externos y actualiza el ConfigMap `tcp-services`.
      4. Devuelve el mapeo de puertos al frontend.
    """
    logger.info(
        "POST /deploy – db_type=%s, class_name=%s, num_students=%d, namespace=%s",
        req.db_type.value, req.class_name, req.num_students, req.namespace,
    )

    try:
        mappings = k8s_manager.deploy_class(
            db_type=req.db_type,
            class_name=req.class_name,
            num_students=req.num_students,
            namespace=req.namespace,
        )
    except RuntimeError as exc:
        logger.error("Error durante el despliegue: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error inesperado durante el despliegue.")
        raise HTTPException(
            status_code=500,
            detail=f"Error inesperado: {exc}",
        ) from exc

    port_mappings = [
        PortMapping(
            student_name=m["student_name"],
            external_port=m["external_port"],
            internal_service=m["internal_service"],
        )
        for m in mappings
    ]

    return DeployResponse(
        message=f"Clase '{req.class_name}' desplegada correctamente con {req.num_students} instancias.",
        release_name=req.class_name,
        port_mappings=port_mappings,
    )


@app.delete("/destroy", response_model=DestroyResponse)
def destroy(req: DestroyRequest) -> DestroyResponse:
    """Elimina un cluster de bases de datos y limpia la configuración de red.

    Flujo:
      1. Ejecuta `helm uninstall`.
      2. Elimina las entradas del ConfigMap `tcp-services`.
    """
    logger.info(
        "DELETE /destroy – db_type=%s, class_name=%s, num_students=%d, namespace=%s",
        req.db_type.value, req.class_name, req.num_students, req.namespace,
    )

    try:
        k8s_manager.destroy_class(
            db_type=req.db_type,
            class_name=req.class_name,
            num_students=req.num_students,
            namespace=req.namespace,
        )
    except RuntimeError as exc:
        logger.error("Error durante la destrucción: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error inesperado durante la destrucción.")
        raise HTTPException(
            status_code=500,
            detail=f"Error inesperado: {exc}",
        ) from exc

    return DestroyResponse(
        message=f"Clase '{req.class_name}' eliminada correctamente.",
        release_name=req.class_name,
    )
