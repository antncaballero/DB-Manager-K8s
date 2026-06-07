locals {
  repo_root               = abspath("${path.module}/../../..")
  build_images_script     = "${local.repo_root}/app/build-k8s-images.sh"
  kubeconfig_path         = pathexpand("~/.kube/config")
  backend_kubeconfig_path = pathexpand(var.backend_kubeconfig_path)
}

resource "terraform_data" "k3d_cluster" {
  input = {
    cluster_name               = var.cluster_name
    agents                     = var.agents
    http_port                  = var.http_port
    https_port                 = var.https_port
    mysql_port_range_start     = var.mysql_port_range_start
    mysql_port_range_end       = var.mysql_port_range_end
    mongo_port_range_start     = var.mongo_port_range_start
    mongo_port_range_end       = var.mongo_port_range_end
    redis_port_range_start     = var.redis_port_range_start
    redis_port_range_end       = var.redis_port_range_end
    cassandra_port_range_start = var.cassandra_port_range_start
    cassandra_port_range_end   = var.cassandra_port_range_end
  }

  provisioner "local-exec" {
    command = <<-EOT
      if k3d kubeconfig get "${self.input.cluster_name}" >/dev/null 2>&1; then
        echo "---- Cluster k3d ${self.input.cluster_name} ya existe."
      else
        echo "---- Creando cluster k3d ${self.input.cluster_name}..."
        k3d cluster create "${self.input.cluster_name}" --k3s-arg "--disable=traefik@server:0" \
          -p "${self.input.http_port}:80@loadbalancer" \
          -p "${self.input.https_port}:443@loadbalancer" \
          -p "${self.input.mysql_port_range_start}-${self.input.mysql_port_range_end}:${self.input.mysql_port_range_start}-${self.input.mysql_port_range_end}@loadbalancer" \
          -p "${self.input.mongo_port_range_start}-${self.input.mongo_port_range_end}:${self.input.mongo_port_range_start}-${self.input.mongo_port_range_end}@loadbalancer" \
          -p "${self.input.redis_port_range_start}-${self.input.redis_port_range_end}:${self.input.redis_port_range_start}-${self.input.redis_port_range_end}@loadbalancer" \
          -p "${self.input.cassandra_port_range_start}-${self.input.cassandra_port_range_end}:${self.input.cassandra_port_range_start}-${self.input.cassandra_port_range_end}@loadbalancer" \
          --agents "${self.input.agents}"
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete \"${self.input.cluster_name}\" || true"
  }
}

resource "terraform_data" "app_images" {
  count = var.build_app_images ? 1 : 0

  input = {
    cluster_name = var.cluster_name
    script_path  = local.build_images_script
  }

  provisioner "local-exec" {
    command = self.input.script_path
    environment = {
      K3D_CLUSTER_NAME = self.input.cluster_name
    }
  }

  depends_on = [terraform_data.k3d_cluster]
}

resource "terraform_data" "backend_kubeconfig" {
  count = var.prepare_backend_kubeconfig ? 1 : 0

  input = {
    cluster_name            = var.cluster_name
    kubeconfig_path         = local.kubeconfig_path
    backend_kubeconfig_path = local.backend_kubeconfig_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      cp "${self.input.kubeconfig_path}" "${self.input.backend_kubeconfig_path}"
      CLUSTER_PORT=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="k3d-${self.input.cluster_name}")].cluster.server}' | cut -d: -f3)
      sed -i "s/0.0.0.0:$${CLUSTER_PORT}/k3d-${self.input.cluster_name}-server-0:6443/g" "${self.input.backend_kubeconfig_path}"
      sed -i "s/127.0.0.1:$${CLUSTER_PORT}/k3d-${self.input.cluster_name}-server-0:6443/g" "${self.input.backend_kubeconfig_path}"
      echo "---- Kubeconfig del backend lista en ${self.input.backend_kubeconfig_path}"
    EOT
  }

  depends_on = [terraform_data.k3d_cluster]
}
