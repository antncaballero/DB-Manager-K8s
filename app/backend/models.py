"""
models.py – Modelos Pydantic para la API del TFG DB Manager.
"""

from enum import Enum
from pydantic import BaseModel, Field


# ── Tipos soportados ─────────────────────────────────────────────────────────

class DBType(str, Enum):
    """Tipos de base de datos que el sistema puede desplegar."""
    MYSQL = "mysql"
    MONGO = "mongo"


# ── Configuración de puertos por tipo de DB ──────────────────────────────────

DB_CONFIG = {
    DBType.MYSQL: {
        "chart_path": "/charts/mysql-class",   # Ruta dentro del contenedor
        "internal_port": 3306,
        "port_range_start": 3306,               # Primer puerto externo asignable
        "port_range_end": 3330,                  # Último puerto externo asignable
    },
    DBType.MONGO: {
        "chart_path": "/charts/mongo-class",
        "internal_port": 27017,
        "port_range_start": 27017,
        "port_range_end": 27040,
    },
}


# ── Request Bodies ────────────────────────────────────────────────────────────

class DeployRequest(BaseModel):
    """Cuerpo de la petición POST /deploy."""
    db_type: DBType = Field(
        ...,
        description="Tipo de base de datos a desplegar (mysql | mongo).",
        examples=["mysql"],
    )
    class_name: str = Field(
        ...,
        min_length=1,
        max_length=63,
        pattern=r"^[a-z0-9][a-z0-9\-]*[a-z0-9]$",
        description="Nombre identificador de la clase (se usa como release de Helm). "
                    "Solo minúsculas, números y guiones; entre 2 y 63 caracteres.",
        examples=["bd-2025-turno1"],
    )
    num_students: int = Field(
        ...,
        gt=0,
        le=25,
        description="Número de alumnos (instancias de DB) a desplegar.",
        examples=[5],
    )
    namespace: str = Field(
        default="default",
        description="Namespace de Kubernetes donde desplegar.",
        examples=["default"],
    )


class DestroyRequest(BaseModel):
    """Cuerpo de la petición DELETE /destroy."""
    db_type: DBType = Field(
        ...,
        description="Tipo de base de datos a eliminar (mysql | mongo).",
        examples=["mysql"],
    )
    class_name: str = Field(
        ...,
        min_length=1,
        max_length=63,
        description="Nombre de la release de Helm a destruir.",
        examples=["bd-2025-turno1"],
    )
    num_students: int = Field(
        ...,
        gt=0,
        le=25,
        description="Número de alumnos (necesario para limpiar los puertos del ConfigMap).",
        examples=[5],
    )
    namespace: str = Field(
        default="default",
        description="Namespace donde se desplegó la release.",
        examples=["default"],
    )


# ── Response Bodies ───────────────────────────────────────────────────────────

class PortMapping(BaseModel):
    """Mapeo de un alumno a su puerto externo."""
    student_name: str
    external_port: int
    internal_service: str


class DeployResponse(BaseModel):
    """Respuesta exitosa de POST /deploy."""
    message: str
    release_name: str
    port_mappings: list[PortMapping]


class DestroyResponse(BaseModel):
    """Respuesta exitosa de DELETE /destroy."""
    message: str
    release_name: str
