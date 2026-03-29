import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import type { DeploymentInfo } from "@/types";

interface Props {
  deployment: DeploymentInfo | null;
  open: boolean;
  loading: boolean;
  onClose: () => void;
  onConfirm: () => void;
}

/**
 * Diálogo de confirmación para destruir un despliegue.
 */
export default function DestroyDialog({
  deployment,
  open,
  loading,
  onClose,
  onConfirm,
}: Props) {
  if (!deployment) return null;

  return (
    <Dialog open={open} onOpenChange={(v) => !v && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Eliminar despliegue</DialogTitle>
          <DialogDescription>
            ¿Seguro que quieres eliminar{" "}
            <span className="font-semibold">{deployment.release_name}</span>? Esta
            acción ejecutará <code>helm uninstall</code> y limpiará todos sus puertos del
            ConfigMap.
          </DialogDescription>
        </DialogHeader>

        <DialogFooter className="gap-2 sm:gap-0">
          <Button variant="outline" onClick={onClose} disabled={loading}>
            Cancelar
          </Button>
          <Button
            variant="destructive"
            disabled={loading}
            onClick={onConfirm}
          >
            {loading ? "Eliminando…" : "Confirmar eliminación"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
