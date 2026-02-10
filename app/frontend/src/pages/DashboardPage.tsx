import { useState } from "react";
import { toast } from "sonner";
import { RefreshCw, ServerOff } from "lucide-react";

import { Button } from "@/components/ui/button";
import DatabaseCard from "@/components/databases/DatabaseCard";
import DestroyDialog from "@/components/databases/DestroyDialog";
import { useDatabases } from "@/hooks/useDatabases";
import { useDestroyDatabase } from "@/hooks/useDestroyDatabase";
import type { DBType, DeploymentInfo } from "@/types";

export default function DashboardPage() {
  const { deployments, loading, error, refresh } = useDatabases();
  const { destroy, loading: destroyLoading } = useDestroyDatabase();

  const [target, setTarget] = useState<DeploymentInfo | null>(null);
  const [destroyingRelease, setDestroyingRelease] = useState<string | null>(null);

  async function handleConfirmDestroy(numStudents: number) {
    if (!target) return;

    setDestroyingRelease(target.release_name);
    try {
      const result = await destroy({
        db_type: target.db_type as DBType,
        class_name: target.release_name,
        num_students: numStudents,
        namespace: target.namespace,
      });
      toast.success(result.message);
      setTarget(null);
      void refresh();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Error al eliminar");
    } finally {
      setDestroyingRelease(null);
    }
  }

  return (
    <div className="space-y-6">
      {/* ── Cabecera ──────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Bases de datos</h1>
          <p className="text-sm text-muted-foreground">
            Despliegues activos gestionados con Helm en el clúster de Kubernetes.
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={refresh} disabled={loading}>
          <RefreshCw className={`mr-1.5 h-4 w-4 ${loading ? "animate-spin" : ""}`} />
          Actualizar
        </Button>
      </div>

      {/* ── Error ─────────────────────────────────────────────────────── */}
      {error && (
        <div className="rounded-md border border-destructive/50 bg-destructive/10 p-4 text-sm text-destructive">
          {error}
        </div>
      )}

      {/* ── Lista ─────────────────────────────────────────────────────── */}
      {!loading && deployments.length === 0 && !error && (
        <div className="flex flex-col items-center gap-3 py-16 text-muted-foreground">
          <ServerOff className="h-10 w-10" />
          <p>No hay despliegues activos.</p>
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {deployments.map((d) => (
          <DatabaseCard
            key={d.release_name}
            deployment={d}
            onDestroy={() => setTarget(d)}
            destroying={destroyingRelease === d.release_name}
          />
        ))}
      </div>

      {/* ── Skeleton mientras carga ───────────────────────────────────── */}
      {loading && deployments.length === 0 && (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div
              key={i}
              className="h-56 animate-pulse rounded-lg border bg-muted/50"
            />
          ))}
        </div>
      )}

      {/* ── Diálogo de destrucción ────────────────────────────────────── */}
      <DestroyDialog
        deployment={target}
        open={target !== null}
        loading={destroyLoading}
        onClose={() => setTarget(null)}
        onConfirm={handleConfirmDestroy}
      />
    </div>
  );
}
