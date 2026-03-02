# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/nginx-ingress/outputs.tf                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

output "ingress_hostname" {
  description = <<-EOT
    Hostname DNS del NLB (Network Load Balancer) creado por AWS.
    Los alumnos usan este hostname + su puerto para conectarse a su base de datos.
    Ejemplo: abc123.elb.eu-west-1.amazonaws.com:3307
  EOT
  value       = try(helm_release.nginx_ingress.status, "pending")
}
