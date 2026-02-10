import DeployForm from "@/components/deploy/DeployForm";

export default function DeployPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Desplegar base de datos</h1>
        <p className="text-sm text-muted-foreground">
          Crea un nuevo cluster de bases de datos para una clase a través de Helm.
        </p>
      </div>

      <DeployForm />
    </div>
  );
}
