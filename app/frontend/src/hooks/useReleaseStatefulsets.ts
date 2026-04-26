import { useCallback, useState } from "react";
import { fetchReleaseStatefulsets } from "@/lib/api";
import type { StatefulSetWakeInfo } from "@/types";

export function useReleaseStatefulsets() {
  const [statefulsets, setStatefulsets] = useState<StatefulSetWakeInfo[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (releaseName: string, namespace: string) => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchReleaseStatefulsets(releaseName, namespace);
      setStatefulsets(data.statefulsets);
    } catch (err) {
      setStatefulsets([]);
      setError(err instanceof Error ? err.message : "Error desconocido");
    } finally {
      setLoading(false);
    }
  }, []);

  const clear = useCallback(() => {
    setStatefulsets([]);
    setError(null);
  }, []);

  return { statefulsets, loading, error, load, clear };
}
