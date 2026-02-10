import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useDeployDatabase } from "@/hooks/useDeployDatabase";
import type { DBType } from "@/types";
import { Rocket } from "lucide-react";

export default function DeployForm() {
  const navigate = useNavigate();
  const { deploy, loading } = useDeployDatabase();

  const [dbType, setDbType] = useState<DBType>("mysql");
  const [className, setClassName] = useState("");
  const [numStudents, setNumStudents] = useState("5");
  const [namespace, setNamespace] = useState("default");

  const classNameValid = /^[a-z0-9][a-z0-9-]*[a-z0-9]$/.test(className);
  const canSubmit =
    className.length >= 2 && classNameValid && +numStudents > 0 && +numStudents <= 25;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;

    try {
      const result = await deploy({
        db_type: dbType,
        class_name: className,
        num_students: Number(numStudents),
        namespace,
      });
      toast.success(result.message);
      navigate("/");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Error al desplegar");
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <Card className="mx-auto max-w-lg">
        <CardHeader>
          <CardTitle>Nuevo despliegue</CardTitle>
          <CardDescription>
            Configura y despliega un cluster de bases de datos para una clase.
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-4">
          {/* Tipo de base de datos */}
          <div className="space-y-2">
            <Label htmlFor="db-type">Tipo de base de datos</Label>
            <Select
              value={dbType}
              onValueChange={(v) => setDbType(v as DBType)}
            >
              <SelectTrigger id="db-type" className="w-full">
                <SelectValue placeholder="Selecciona tipo" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="mysql">MySQL</SelectItem>
                <SelectItem value="mongo">MongoDB</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Nombre de la clase */}
          <div className="space-y-2">
            <Label htmlFor="class-name">Nombre de la clase</Label>
            <Input
              id="class-name"
              placeholder="bd-2025-turno1"
              value={className}
              onChange={(e) => setClassName(e.target.value.toLowerCase())}
            />
            {className.length > 0 && !classNameValid && (
              <p className="text-xs text-destructive">
                Solo minúsculas, números y guiones. Mín. 2 caracteres. Debe empezar y
                terminar en alfanumérico.
              </p>
            )}
          </div>

          {/* Número de alumnos */}
          <div className="space-y-2">
            <Label htmlFor="num-students">Nº de alumnos (instancias)</Label>
            <Input
              id="num-students"
              type="number"
              min={1}
              max={25}
              value={numStudents}
              onChange={(e) => setNumStudents(e.target.value)}
            />
          </div>

          {/* Namespace */}
          <div className="space-y-2">
            <Label htmlFor="namespace">Namespace</Label>
            <Input
              id="namespace"
              placeholder="default"
              value={namespace}
              onChange={(e) => setNamespace(e.target.value)}
            />
          </div>
        </CardContent>

        <CardFooter>
          <Button type="submit" className="w-full" disabled={!canSubmit || loading}>
            <Rocket className="mr-1.5 h-4 w-4" />
            {loading ? "Desplegando…" : "Desplegar"}
          </Button>
        </CardFooter>
      </Card>
    </form>
  );
}
