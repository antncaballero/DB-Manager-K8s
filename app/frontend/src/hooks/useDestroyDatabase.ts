import { useCallback, useState } from "react";
import { destroyDatabase } from "@/lib/api";
import type { DestroyRequest, DestroyResponse } from "@/types";

/**
 * Hook para destruir un despliegue de base de datos.
 */
export function useDestroyDatabase() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const destroy = useCallback(async (req: DestroyRequest): Promise<DestroyResponse> => {
    setLoading(true);
    setError(null);
    try {
      const result = await destroyDatabase(req);
      return result;
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Error desconocido";
      setError(msg);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  return { destroy, loading, error };
}
