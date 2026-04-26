import { useCallback, useState } from "react";
import { wakeStatefulset } from "@/lib/api";
import type { WakeStatefulSetResponse } from "@/types";

export function useWakeStatefulset() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const wake = useCallback(
    async (
      releaseName: string,
      statefulsetName: string,
      namespace: string,
    ): Promise<WakeStatefulSetResponse> => {
      setLoading(true);
      setError(null);
      try {
        const result = await wakeStatefulset(releaseName, statefulsetName, namespace);
        return result;
      } catch (err) {
        const msg = err instanceof Error ? err.message : "Error desconocido";
        setError(msg);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  return { wake, loading, error };
}
