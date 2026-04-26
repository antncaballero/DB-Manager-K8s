import { useEffect, useMemo, useState } from "react";
import { toast } from "sonner";
import { Loader2, Moon, Power, RefreshCw } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useReleaseStatefulsets } from "@/hooks/useReleaseStatefulsets";
import { useWakeReleases } from "@/hooks/useWakeReleases";
import { useWakeStatefulset } from "@/hooks/useWakeStatefulset";
import type { StatefulSetWakeInfo } from "@/types";

function statusVariant(status: string) {
  if (status === "active") return "default" as const;
  if (status === "hibernating") return "secondary" as const;
  return "secondary" as const;
}

function statusLabel(status: string) {
  if (status === "active") return "Activo";
  if (status === "starting") return "Iniciando";
  if (status === "hibernating") return "Hibernando";
  return status;
}

function dbLabel(dbType: string) {
  if (dbType === "mysql") return "MySQL";
  if (dbType === "mongo") return "MongoDB";
  if (dbType === "redis") return "Redis";
  if (dbType === "cassandra") return "Cassandra";
  return dbType;
}

function releaseKey(releaseName: string, namespace: string) {
  return `${namespace}/${releaseName}`;
}

function statefulsetKey(item: StatefulSetWakeInfo) {
  return `${item.namespace}/${item.name}`;
}

export default function WakePage() {
  const { releases, loading: releasesLoading, error: releasesError, refresh: refreshReleases } = useWakeReleases();
  const {
    statefulsets,
    loading: statefulsetsLoading,
    error: statefulsetsError,
    load: loadStatefulsets,
    clear: clearStatefulsets,
  } = useReleaseStatefulsets();
  const { wake, loading: wakeLoading } = useWakeStatefulset();

  const [selectedReleaseKey, setSelectedReleaseKey] = useState("");
  const [wakingItemKey, setWakingItemKey] = useState<string | null>(null);

  const selectedRelease = useMemo(
    () => releases.find((r) => releaseKey(r.release_name, r.namespace) === selectedReleaseKey),
    [releases, selectedReleaseKey],
  );

  useEffect(() => {
    if (!selectedReleaseKey) return;

    const exists = releases.some((r) => releaseKey(r.release_name, r.namespace) === selectedReleaseKey);
    if (!exists) {
      setSelectedReleaseKey("");
      clearStatefulsets();
    }
  }, [releases, selectedReleaseKey, clearStatefulsets]);

  async function handleSelectRelease(nextKey: string) {
    setSelectedReleaseKey(nextKey);

    const selected = releases.find((r) => releaseKey(r.release_name, r.namespace) === nextKey);
    if (!selected) {
      clearStatefulsets();
      return;
    }

    await loadStatefulsets(selected.release_name, selected.namespace);
  }

  async function handleWake(item: StatefulSetWakeInfo) {
    if (!selectedRelease) return;

    const itemKey = statefulsetKey(item);
    setWakingItemKey(itemKey);

    try {
      const result = await wake(selectedRelease.release_name, item.name, selectedRelease.namespace);
      toast.success(result.message);
      await loadStatefulsets(selectedRelease.release_name, selectedRelease.namespace);
      await refreshReleases();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Error al despertar StatefulSet");
    } finally {
      setWakingItemKey(null);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Despertar StatefulSets</h1>
          <p className="text-sm text-muted-foreground">
            Selecciona una release y despierta solo los StatefulSets que estén hibernados.
          </p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => {
            void refreshReleases();
            if (selectedRelease) {
              void loadStatefulsets(selectedRelease.release_name, selectedRelease.namespace);
            }
          }}
          disabled={releasesLoading || statefulsetsLoading}
        >
          <RefreshCw className={`mr-1.5 h-4 w-4 ${releasesLoading || statefulsetsLoading ? "animate-spin" : ""}`} />
          Actualizar
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Release</CardTitle>
          <CardDescription>
            Elige la release para cargar sus StatefulSets.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="space-y-2">
            <Label htmlFor="release-select">Release</Label>
            <Select value={selectedReleaseKey} onValueChange={handleSelectRelease}>
              <SelectTrigger id="release-select" className="w-full" disabled={releasesLoading || releases.length === 0}>
                <SelectValue placeholder={releasesLoading ? "Cargando releases..." : "Selecciona una release"} />
              </SelectTrigger>
              <SelectContent>
                {releases.map((release) => (
                  <SelectItem
                    key={releaseKey(release.release_name, release.namespace)}
                    value={releaseKey(release.release_name, release.namespace)}
                  >
                    {release.release_name} · {release.namespace} · {dbLabel(release.db_type)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {releasesError && (
            <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
              {releasesError}
            </div>
          )}

          {!releasesLoading && releases.length === 0 && !releasesError && (
            <div className="rounded-md border bg-muted/40 p-3 text-sm text-muted-foreground">
              No hay releases disponibles para despertar.
            </div>
          )}
        </CardContent>
      </Card>

      {selectedRelease && (
        <Card>
          <CardHeader>
            <CardTitle>{selectedRelease.release_name}</CardTitle>
            <CardDescription>
              Namespace: {selectedRelease.namespace}
            </CardDescription>
          </CardHeader>

          <CardContent className="space-y-3">
            {statefulsetsError && (
              <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
                {statefulsetsError}
              </div>
            )}

            {statefulsetsLoading && (
              <div className="space-y-2">
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="h-12 animate-pulse rounded-md border bg-muted/40" />
                ))}
              </div>
            )}

            {!statefulsetsLoading && statefulsets.length === 0 && !statefulsetsError && (
              <div className="rounded-md border bg-muted/40 p-3 text-sm text-muted-foreground">
                Esta release no tiene StatefulSets disponibles.
              </div>
            )}

            {!statefulsetsLoading && statefulsets.length > 0 && (
              <div className="space-y-2">
                {statefulsets.map((item) => {
                  const isWaking = wakeLoading && wakingItemKey === statefulsetKey(item);
                  return (
                    <div
                      key={statefulsetKey(item)}
                      className="flex items-center justify-between gap-3 rounded-md border p-3"
                    >
                      <div className="min-w-0 space-y-1">
                        <p className="truncate text-sm font-medium">{item.name}</p>
                        <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                          <Badge variant={statusVariant(item.status)} className={item.status === "hibernating" ? "bg-yellow-500/15 text-yellow-700" : undefined}>
                            {statusLabel(item.status)}
                          </Badge>
                          <span>Réplicas: {item.ready_replicas}/{item.desired_replicas}</span>
                        </div>
                      </div>

                      <Button
                        size="sm"
                        variant={item.can_wake ? "default" : "secondary"}
                        disabled={!item.can_wake || isWaking}
                        onClick={() => void handleWake(item)}
                      >
                        {isWaking ? <Loader2 className="mr-1.5 h-4 w-4 animate-spin" /> : item.can_wake ? <Power className="mr-1.5 h-4 w-4" /> : <Moon className="mr-1.5 h-4 w-4" />}
                        {isWaking ? "Despertando…" : item.can_wake ? "Despertar" : "Activo"}
                      </Button>
                    </div>
                  );
                })}
              </div>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  );
}
