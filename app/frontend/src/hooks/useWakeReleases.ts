import { useCallback, useEffect, useState } from "react";
import { fetchWakeReleases } from "@/lib/api";
import type { WakeReleaseOption } from "@/types";

export function useWakeReleases() {
  const [releases, setReleases] = useState<WakeReleaseOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchWakeReleases();
      setReleases(data.releases);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Error desconocido");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  return { releases, loading, error, refresh };
}
