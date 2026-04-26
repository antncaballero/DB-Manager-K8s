// ── Tipos compartidos con la API del backend ────────────────────────────────

export type DBType = "mysql" | "mongo";

export interface PortMapping {
  student_name: string;
  external_port: number;
  internal_service: string;
}

export interface DeployRequest {
  db_type: DBType;
  class_name: string;
  num_students: number;
  namespace: string;
}

export interface DeployResponse {
  message: string;
  release_name: string;
  port_mappings: PortMapping[];
}

export interface DestroyRequest {
  class_name: string;
  namespace: string;
}

export interface DestroyResponse {
  message: string;
  release_name: string;
}

export interface WakeDeploymentResponse {
  message: string;
  release_name: string;
  namespace: string;
}

export interface WakeStatefulSetResponse {
  message: string;
  release_name: string;
  namespace: string;
  statefulset_name: string;
  already_active: boolean;
}

export interface ConnectionMapping {
  student_name: string;
  external_port: number;
  internal_service: string;
}

export interface DeploymentInfo {
  release_name: string;
  namespace: string;
  db_type: string;
  chart: string;
  status: "active" | "starting" | "hibernating" | string;
  updated: string;
  statefulsets: number;
  ready_instances: number;
  external_ip: string;
  port_mappings: ConnectionMapping[];
}

export interface ListDeploymentsResponse {
  deployments: DeploymentInfo[];
}

export interface WakeReleaseOption {
  release_name: string;
  namespace: string;
  db_type: string;
  status: string;
  statefulsets: number;
}

export interface ListWakeReleasesResponse {
  releases: WakeReleaseOption[];
}

export interface StatefulSetWakeInfo {
  name: string;
  namespace: string;
  release_name: string;
  desired_replicas: number;
  ready_replicas: number;
  status: "active" | "starting" | "hibernating" | string;
  can_wake: boolean;
}

export interface ListReleaseStatefulSetsResponse {
  release_name: string;
  namespace: string;
  statefulsets: StatefulSetWakeInfo[];
}
