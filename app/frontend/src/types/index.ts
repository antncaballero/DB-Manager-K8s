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
  db_type: DBType;
  class_name: string;
  num_students: number;
  namespace: string;
}

export interface DestroyResponse {
  message: string;
  release_name: string;
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
  status: string;
  updated: string;
  statefulsets: number;
  ready_instances: number;
  external_ip: string;
  port_mappings: ConnectionMapping[];
}

export interface ListDeploymentsResponse {
  deployments: DeploymentInfo[];
}
