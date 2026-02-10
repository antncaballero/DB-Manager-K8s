import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { DeploymentInfo } from "@/types";
import { useState } from "react";

interface Props {
  deployment: DeploymentInfo | null;
  open: boolean;
  loading: boolean;
  onClose: () => void;
  onConfirm: (numStudents: number) => void;
}

/**
 * Diálogo de confirmación para destruir un despliegue.
 * Pide el número de alumnos (necesario para limpiar el ConfigMap).
 */
export default function DestroyDialog({
  deployment,
  open,
  loading,
  onClose,
  onConfirm,
}: Props) {
  const [numStudents, setNumStudents] = useState("1");

  if (!deployment) return null;

  return (
    <Dialog open={open} onOpenChange={(v) => !v && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Eliminar despliegue</DialogTitle>
          <DialogDescription>
            ¿Seguro que quieres eliminar{" "}
            <span className="font-semibold">{deployment.release_name}</span>? Esta
            acción ejecutará <code>helm uninstall</code> y limpiará la configuración de
            puertos.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-2 py-2">
          <Label htmlFor="num-students-destroy">Nº de alumnos del despliegue</Label>
          <Input
            id="num-students-destroy"
            type="number"
            min={1}
            max={25}
            value={numStudents}
            onChange={(e) => setNumStudents(e.target.value)}
          />
          <p className="text-xs text-muted-foreground">
            Necesario para limpiar las entradas de puertos del ConfigMap.
          </p>
        </div>

        <DialogFooter className="gap-2 sm:gap-0">
          <Button variant="outline" onClick={onClose} disabled={loading}>
            Cancelar
          </Button>
          <Button
            variant="destructive"
            disabled={loading || !numStudents || +numStudents < 1}
            onClick={() => onConfirm(Number(numStudents))}
          >
            {loading ? "Eliminando…" : "Confirmar eliminación"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
