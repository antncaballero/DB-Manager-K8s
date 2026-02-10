import { useCallback, useState } from "react";
import { deployDatabase } from "@/lib/api";
import type { DeployRequest, DeployResponse } from "@/types";

/**
 * Hook para desplegar una nueva base de datos.
 */
export function useDeployDatabase() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<DeployResponse | null>(null);

  const deploy = useCallback(async (req: DeployRequest) => {
    setLoading(true);
    setError(null);
    setData(null);
    try {
      const result = await deployDatabase(req);
      setData(result);
      return result;
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Error desconocido";
      setError(msg);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  return { deploy, loading, error, data };
}
