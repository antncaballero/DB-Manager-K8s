# ╔═════════════════════════════════════════════════════════════════════════════╗
# ║  modules/storage/main.tf – StorageClass para volúmenes persistentes         ║
# ║                                                                             ║
# ║  En k3d, los PVC usan StorageClass "local-path" (almacenamiento local).     ║
# ║  En AWS/EKS, necesitamos una StorageClass que use EBS (discos virtuales).   ║
# ║                                                                             ║
# ║  Creamos una StorageClass "gp3" (la más moderna y eficiente de AWS) y la    ║
# ║  marcamos como default para que los charts de Helm la usen automáticamente. ║
# ║                                                                             ║
# ║  Tipo gp3 = SSD de propósito general, 3000 IOPS incluidas, muy económico.   ║
# ╚═════════════════════════════════════════════════════════════════════════════╝

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      # Marcar como StorageClass por defecto → si un PVC no especifica
      # storageClassName, usará esta automáticamente.
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  # Provisioner: el EBS CSI Driver que instalamos como addon de EKS
  storage_provisioner = "ebs.csi.aws.com"

  # Política de reclamación: qué pasa con el disco cuando se borra el PVC
  # "Delete" = el disco EBS se borra automáticamente (evita costes huérfanos)
  reclaim_policy = "Delete"

  # Permitir expandir volúmenes sin recrearlos
  allow_volume_expansion = true

  # Modo de binding: esperar a que un pod lo necesite antes de crear el disco
  # Así el disco se crea en la misma AZ que el pod
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"   # SSD de propósito general (3ª gen, más eficiente que gp2)
    fsType    = "ext4"  # Sistema de archivos
    encrypted = "true"  # Cifrado en reposo (buena práctica)
  }
}
