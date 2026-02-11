import { useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import type { DeploymentInfo } from "@/types";
import { ChevronDown, ChevronUp, Globe, ServerCrash, Trash2 } from "lucide-react";

interface Props {
  deployment: DeploymentInfo;
  onDestroy: (d: DeploymentInfo) => void;
  destroying: boolean;
}

function statusVariant(status: string) {
  if (status === "deployed") return "default" as const;
  if (status === "failed") return "destructive" as const;
  return "secondary" as const;
}

function dbLabel(dbType: string) {
  if (dbType === "mysql") return "MySQL";
  if (dbType === "mongo") return "MongoDB";
  return dbType;
}

export default function DatabaseCard({ deployment, onDestroy, destroying }: Props) {
  const [showConnections, setShowConnections] = useState(false);

  const updatedShort = deployment.updated
    ? new Date(deployment.updated).toLocaleString("es-ES", {
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      })
    : "—";

  const hasConnections =
    deployment.external_ip && deployment.port_mappings.length > 0;

  const portRange = hasConnections
    ? deployment.port_mappings.length === 1
      ? `${deployment.port_mappings[0].external_port}`
      : `${deployment.port_mappings[0].external_port}–${deployment.port_mappings[deployment.port_mappings.length - 1].external_port}`
    : null;

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between">
          <div>
            <CardTitle className="text-base font-semibold">
              {deployment.release_name}
            </CardTitle>
            <CardDescription className="mt-1 text-xs">
              Namespace: <span className="font-medium">{deployment.namespace}</span>
            </CardDescription>
          </div>
          <Badge variant={statusVariant(deployment.status)}>
            {deployment.status}
          </Badge>
        </div>
      </CardHeader>

      <CardContent className="space-y-2 text-sm">
        <div className="flex items-center justify-between">
          <span className="text-muted-foreground">Tipo</span>
          <Badge variant="outline">{dbLabel(deployment.db_type)}</Badge>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-muted-foreground">Chart</span>
          <span className="font-mono text-xs">{deployment.chart}</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-muted-foreground">StatefulSets</span>
          <span>{deployment.statefulsets}</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-muted-foreground">Instancias listas</span>
          <span>{deployment.ready_instances}</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-muted-foreground">Actualizado</span>
          <span className="text-xs">{updatedShort}</span>
        </div>

        {/* ── Información de conexión ───────────────────────────────── */}
        {hasConnections && (
          <>
            <Separator className="my-2" />
            <div className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
              <Globe className="h-3.5 w-3.5" />
              Conexión
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">IP externa</span>
              <span className="font-mono text-xs font-medium">
                {deployment.external_ip}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Puertos</span>
              <span className="font-mono text-xs font-medium">
                {portRange}
              </span>
            </div>

            <Button
              variant="ghost"
              size="sm"
              className="h-7 w-full text-xs"
              onClick={() => setShowConnections(!showConnections)}
            >
              {showConnections ? (
                <ChevronUp className="mr-1 h-3 w-3" />
              ) : (
                <ChevronDown className="mr-1 h-3 w-3" />
              )}
              {showConnections
                ? "Ocultar detalle"
                : `Ver ${deployment.port_mappings.length} conexiones`}
            </Button>

            {showConnections && (
              <div className="space-y-1 rounded-md border bg-muted/40 p-2">
                {deployment.port_mappings.map((pm) => (
                  <div
                    key={pm.external_port}
                    className="flex items-center justify-between text-xs"
                  >
                    <span className="text-muted-foreground">{pm.student_name}</span>
                    <code className="rounded bg-background px-1.5 py-0.5 font-mono text-[11px]">
                      {deployment.external_ip}:{pm.external_port}
                    </code>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </CardContent>

      <CardFooter>
        <Button
          variant="destructive"
          size="sm"
          className="w-full"
          disabled={destroying}
          onClick={() => onDestroy(deployment)}
        >
          {destroying ? (
            <ServerCrash className="mr-1.5 h-4 w-4 animate-pulse" />
          ) : (
            <Trash2 className="mr-1.5 h-4 w-4" />
          )}
          {destroying ? "Eliminando…" : "Eliminar"}
        </Button>
      </CardFooter>
    </Card>
  );
}
