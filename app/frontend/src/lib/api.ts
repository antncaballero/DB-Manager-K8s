// ── Servicio de comunicación con la API FastAPI ─────────────────────────────

import type {
  DeployRequest,
  DeployResponse,
  DestroyRequest,
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

export function wakeDeployment(releaseName: string, namespace: string) {
  const releaseEncoded = encodeURIComponent(releaseName);
  const namespaceEncoded = encodeURIComponent(namespace);
  return request<WakeDeploymentResponse>(
    `/deployments/${releaseEncoded}/wake?namespace=${namespaceEncoded}`,
    {
      method: "POST",
    },
  );
}

export function fetchWakeReleases(namespace?: string) {
  const qs = namespace ? `?namespace=${encodeURIComponent(namespace)}` : "";
  return request<ListWakeReleasesResponse>(`/wake/releases${qs}`);
}

export function fetchReleaseStatefulsets(releaseName: string, namespace: string) {
  const releaseEncoded = encodeURIComponent(releaseName);
  const namespaceEncoded = encodeURIComponent(namespace);
  return request<ListReleaseStatefulSetsResponse>(
    `/wake/releases/${releaseEncoded}/statefulsets?namespace=${namespaceEncoded}`,
  );
}

export function wakeStatefulset(
  releaseName: string,
  statefulsetName: string,
  namespace: string,
) {
  const releaseEncoded = encodeURIComponent(releaseName);
  const statefulsetEncoded = encodeURIComponent(statefulsetName);
  const namespaceEncoded = encodeURIComponent(namespace);
  return request<WakeStatefulSetResponse>(
    `/wake/releases/${releaseEncoded}/statefulsets/${statefulsetEncoded}?namespace=${namespaceEncoded}`,
    {
      method: "POST",
    },
  );
}
