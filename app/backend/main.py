"""
main.py – API REST del TFG DB Manager.

Endpoints:
  POST   /deploy   → Despliega un cluster de BBDDs para una clase.
  DELETE  /destroy  → Elimina el cluster y limpia la configuración de red.
  GET    /health    → Healthcheck básico.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from models import (
    DeployRequest,
    DeployResponse,
    DeploymentInfo,
    DestroyRequest,
    DestroyResponse,
    ListReleaseStatefulSetsResponse,
    ListDeploymentsResponse,
    ListWakeReleasesResponse,
    PortMapping,
    StatefulSetWakeInfo,
    WakeReleaseOption,
    WakeDeploymentResponse,
    WakeStatefulSetResponse,
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


async def hibernation_worker() -> None:
    """Bucle de hibernación automática para StatefulSets inactivos."""
    while True:
        try:
            active_statefulsets = k8s_manager.list_active_statefulsets()
            for statefulset in active_statefulsets:
                statefulset_name = statefulset.get("name", "")
                statefulset_namespace = statefulset.get("namespace", "default")
                if not statefulset_name:
                    continue

                try:
                    is_idle = k8s_manager.is_statefulset_idle(
                        namespace=statefulset_namespace,
                        statefulset_name=statefulset_name,
                    )
                except Exception as exc:
                    logger.warning(
                        "No se pudo evaluar inactividad de %s/%s: %s",
                        statefulset_namespace,
                        statefulset_name,
                        exc,
                    )
                    continue

                if is_idle:
                    logger.info(
                        "Hibernando StatefulSet por inactividad: %s/%s",
                        statefulset_namespace,
                        statefulset_name,
                    )
                    k8s_manager.scale_statefulset(
                        statefulset_name,
                        statefulset_namespace,
                        replicas=0,
                    )
        except asyncio.CancelledError:
            logger.info("Hibernation worker detenido.")
            break
        except Exception:
            logger.exception("Error inesperado en hibernation worker.")

        # await asyncio.sleep(600)
        await asyncio.sleep(180)  # Para pruebas, hibernar cada 3 minutos


@app.on_event("startup")
async def startup_hibernation_worker() -> None:
    app.state.hibernation_task = asyncio.create_task(hibernation_worker())
    logger.info("Hibernation worker iniciado.")


@app.on_event("shutdown")
async def shutdown_hibernation_worker() -> None:
    task = getattr(app.state, "hibernation_task", None)
    if task:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task


# ═══════════════════════════════════════════════════════════════════════════════
#  ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════════

@app.get("/health")
def health_check() -> dict[str, str]:
    """Healthcheck simple para Docker / K8s liveness probes."""
    return {"status": "ok"}


@app.get("/deployments", response_model=ListDeploymentsResponse)
def list_deployments(namespace: str | None = None) -> ListDeploymentsResponse:
    """Lista los despliegues activos de bases de datos gestionados por Helm."""
    logger.info("GET /deployments – namespace=%s", namespace)

    try:
        raw = k8s_manager.list_deployments(namespace=namespace)
    except Exception as exc:
        logger.exception("Error al listar despliegues.")
        raise HTTPException(
            status_code=500,
            detail=f"Error al listar despliegues: {exc}",
        ) from exc

    deployments = [DeploymentInfo(**d) for d in raw]
    return ListDeploymentsResponse(deployments=deployments)


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
        "DELETE /destroy – class_name=%s, namespace=%s",
        req.class_name, req.namespace,
    )

    try:
        k8s_manager.destroy_class(
            class_name=req.class_name,
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


@app.post("/deployments/{release_name}/wake", response_model=WakeDeploymentResponse)
def wake_deployment(
    release_name: str,
    namespace: str = Query(default="default"),
) -> WakeDeploymentResponse:
    """Despierta un despliegue hibernado escalando a 1 todos sus StatefulSets."""
    logger.info("POST /deployments/%s/wake – namespace=%s", release_name, namespace)

    try:
        k8s_manager.wake_release(
            release_name=release_name,
            namespace=namespace,
            timeout_seconds=90,
        )
    except RuntimeError as exc:
        logger.error("Error durante el wake de %s/%s: %s", namespace, release_name, exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Error inesperado durante wake de %s/%s.", namespace, release_name)
        raise HTTPException(
            status_code=500,
            detail=f"Error inesperado en wake: {exc}",
        ) from exc

    return WakeDeploymentResponse(
        message=f"Entorno '{release_name}' despertado correctamente.",
        release_name=release_name,
        namespace=namespace,
    )


@app.get("/wake/releases", response_model=ListWakeReleasesResponse)
def list_wake_releases(namespace: str | None = None) -> ListWakeReleasesResponse:
    """Lista releases disponibles para wakeup granular."""
    logger.info("GET /wake/releases – namespace=%s", namespace)

    try:
        raw = k8s_manager.list_wake_releases(namespace=namespace)
    except Exception as exc:
        logger.exception("Error al listar releases para wakeup.")
        raise HTTPException(
            status_code=500,
            detail=f"Error al listar releases para wakeup: {exc}",
        ) from exc

    releases = [WakeReleaseOption(**release) for release in raw]
    return ListWakeReleasesResponse(releases=releases)


@app.get(
    "/wake/releases/{release_name}/statefulsets",
    response_model=ListReleaseStatefulSetsResponse,
)
def list_release_statefulsets(
    release_name: str,
    namespace: str = Query(default="default"),
) -> ListReleaseStatefulSetsResponse:
    """Lista StatefulSets de una release para wakeup individual."""
    logger.info(
        "GET /wake/releases/%s/statefulsets – namespace=%s",
        release_name,
        namespace,
    )

    try:
        raw = k8s_manager.list_release_statefulsets(
            release_name=release_name,
            namespace=namespace,
        )
    except RuntimeError as exc:
        logger.error(
            "Error al listar StatefulSets de %s/%s: %s",
            namespace,
            release_name,
            exc,
        )
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception(
            "Error inesperado al listar StatefulSets de %s/%s.",
            namespace,
            release_name,
        )
        raise HTTPException(
            status_code=500,
            detail=f"Error inesperado al listar StatefulSets: {exc}",
        ) from exc

    statefulsets = [StatefulSetWakeInfo(**item) for item in raw]
    return ListReleaseStatefulSetsResponse(
        release_name=release_name,
        namespace=namespace,
        statefulsets=statefulsets,
    )


@app.post(
    "/wake/releases/{release_name}/statefulsets/{statefulset_name}",
    response_model=WakeStatefulSetResponse,
)
def wake_single_statefulset(
    release_name: str,
    statefulset_name: str,
    namespace: str = Query(default="default"),
) -> WakeStatefulSetResponse:
    """Despierta un StatefulSet concreto de una release."""
    logger.info(
        "POST /wake/releases/%s/statefulsets/%s – namespace=%s",
        release_name,
        statefulset_name,
        namespace,
    )

    try:
        woke = k8s_manager.wake_statefulset(
            release_name=release_name,
            statefulset_name=statefulset_name,
            namespace=namespace,
            timeout_seconds=90,
        )
    except RuntimeError as exc:
        logger.error(
            "Error al despertar StatefulSet %s en %s/%s: %s",
            statefulset_name,
            namespace,
            release_name,
            exc,
        )
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception(
            "Error inesperado durante wake de %s en %s/%s.",
            statefulset_name,
            namespace,
            release_name,
        )
        raise HTTPException(
            status_code=500,
            detail=f"Error inesperado en wake de StatefulSet: {exc}",
        ) from exc

    if woke:
        message = (
            f"StatefulSet '{statefulset_name}' despertado correctamente "
            f"en release '{release_name}'."
        )
    else:
        message = (
            f"StatefulSet '{statefulset_name}' ya estaba activo "
            f"en release '{release_name}'."
        )

    return WakeStatefulSetResponse(
        message=message,
        release_name=release_name,
        namespace=namespace,
        statefulset_name=statefulset_name,
        already_active=not woke,
    )
