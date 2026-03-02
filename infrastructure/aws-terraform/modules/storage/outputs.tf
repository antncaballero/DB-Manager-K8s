# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  modules/storage/outputs.tf                                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

output "storage_class_name" {
  description = "Nombre del StorageClass creado (gp3)."
  value       = kubernetes_storage_class.gp3.metadata[0].name
}
