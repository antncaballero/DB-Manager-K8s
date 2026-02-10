// ── Servicio de comunicación con la API FastAPI ─────────────────────────────

import type {
  DeployRequest,
  DeployResponse,
  DestroyRequest,
  DestroyResponse,
  ListDeploymentsResponse,
} from "@/types";

/**
 * Base URL de la API.
 * En desarrollo local apunta al backend directo; en producción pasa por el proxy Nginx.
 */
const API_BASE = import.meta.env.VITE_API_URL ?? "/api";

async function request<T>(
  endpoint: string,
  options: RequestInit = {},
): Promise<T> {
  const url = `${API_BASE}${endpoint}`;

  const res = await fetch(url, {
    headers: { "Content-Type": "application/json", ...options.headers },
    ...options,
  });

  if (!res.ok) {
    const body = await res.json().catch(() => null);
    const detail = body?.detail ?? res.statusText;
    throw new Error(detail);
  }

  return res.json() as Promise<T>;
}

// ── Endpoints ────────────────────────────────────────────────────────────────

export function fetchDeployments(namespace?: string) {
  const qs = namespace ? `?namespace=${encodeURIComponent(namespace)}` : "";
  return request<ListDeploymentsResponse>(`/deployments${qs}`);
}

export function deployDatabase(body: DeployRequest) {
  return request<DeployResponse>("/deploy", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

export function destroyDatabase(body: DestroyRequest) {
  return request<DestroyResponse>("/destroy", {
    method: "DELETE",
    body: JSON.stringify(body),
  });
}

export function healthCheck() {
  return request<{ status: string }>("/health");
}
