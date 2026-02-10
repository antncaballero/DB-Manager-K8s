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
import type { DeploymentInfo } from "@/types";
import { ServerCrash, Trash2 } from "lucide-react";

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
  const updatedShort = deployment.updated
    ? new Date(deployment.updated).toLocaleString("es-ES", {
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      })
    : "—";

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
