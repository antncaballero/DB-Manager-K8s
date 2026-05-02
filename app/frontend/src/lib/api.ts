// ── Servicio de comunicación con la API FastAPI ─────────────────────────────

import type {
  DeployRequest,
  DeployResponse,
  DestroyResponse,
  ListReleaseStatefulSetsResponse,
  ListDeploymentsResponse,
  ListWakeReleasesResponse,
  WakeDeploymentResponse,
  WakeStatefulSetResponse,
} from "@/types";

/**
 * Base URL de la API
 */
const API_BASE = import.meta.env.VITE_API_URL ?? "/api";

export class ApiHttpError extends Error {
  status: number;
  detail?: unknown;

  constructor(status: number, message: string, detail?: unknown) {
    super(message);
    this.name = "ApiHttpError";
    this.status = status;
    this.detail = detail;
  }
}

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
    const detail = body?.detail ?? res.statusText ?? "HTTP error";
    throw new ApiHttpError(res.status, String(detail), body);
  }

  return res.json() as Promise<T>;
}

// ── Endpoints ────────────────────────────────────────────────────────────────

export function fetchDeployments(namespace?: string) {
  const qs = namespace ? `?namespace=${encodeURIComponent(namespace)}` : "";
  return request<ListDeploymentsResponse>(`/deployments${qs}`);
}

export function deployDatabase(body: DeployRequest) {
  return request<DeployResponse>("/deployments", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

export function destroyDatabase(namespace: string, releaseName: string) {
  return request<DestroyResponse>(`/deployments/${encodeURIComponent(namespace)}/${encodeURIComponent(releaseName)}`, {
    method: "DELETE",
  });
}

export function healthCheck() {
  return request<{ status: string }>("/health");
}

export function wakeDeployment(namespace: string, releaseName: string) {
  const releaseEncoded = encodeURIComponent(releaseName);
  const namespaceEncoded = encodeURIComponent(namespace);
  return request<WakeDeploymentResponse>(
    `/deployments/${namespaceEncoded}/${releaseEncoded}`,
    {
      method: "PATCH",
    }
  );
}

export function fetchWakeReleases(namespace?: string) {
  const qs = namespace ? `?namespace=${encodeURIComponent(namespace)}` : "";
  return request<ListWakeReleasesResponse>(`/deployments/hibernated${qs}`);
}

export function fetchReleaseStatefulsets(namespace: string, releaseName: string) {
  const releaseEncoded = encodeURIComponent(releaseName);
  const namespaceEncoded = encodeURIComponent(namespace);
  return request<ListReleaseStatefulSetsResponse>(
    `/deployments/${namespaceEncoded}/${releaseEncoded}/statefulsets`,
  );
}

export function wakeStatefulset(
  namespace: string,
  releaseName: string,
  statefulsetName: string,
) {
  const releaseEncoded = encodeURIComponent(releaseName);
  const statefulsetEncoded = encodeURIComponent(statefulsetName);
  const namespaceEncoded = encodeURIComponent(namespace);
  return request<WakeStatefulSetResponse>(
    `/deployments/${namespaceEncoded}/${releaseEncoded}/statefulsets/${statefulsetEncoded}`,
    {
      method: "PATCH",
    },
  );
}
