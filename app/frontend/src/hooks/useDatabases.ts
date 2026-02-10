import { useCallback, useEffect, useState } from "react";
import { fetchDeployments } from "@/lib/api";
import type { DeploymentInfo } from "@/types";

/**
 * Hook para obtener y refrescar la lista de despliegues activos.
 */
export function useDatabases() {
  const [deployments, setDeployments] = useState<DeploymentInfo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchDeployments();
      setDeployments(data.deployments);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Error desconocido");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return { deployments, loading, error, refresh };
}
