import { useCallback, useState } from "react";
import { wakeDeployment } from "@/lib/api";
import type { WakeDeploymentResponse } from "@/types";

/**
 * Hook para despertar un despliegue hibernado.
 */
export function useWakeDatabase() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const wake = useCallback(
    async (releaseName: string, namespace: string): Promise<WakeDeploymentResponse> => {
      setLoading(true);
      setError(null);
      try {
        const result = await wakeDeployment(releaseName, namespace);
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
