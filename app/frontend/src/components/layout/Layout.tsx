import { Link, Outlet, useLocation } from "react-router-dom";
import { Database, Rocket } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";

const NAV_ITEMS = [
  { to: "/", label: "Bases de datos", icon: Database },
  { to: "/deploy", label: "Desplegar", icon: Rocket },
] as const;

export default function Layout() {
  const { pathname } = useLocation();

  return (
    <div className="min-h-screen bg-background">
      {/* ── Header / Navbar ─────────────────────────────────────────────── */}
      <header className="sticky top-0 z-50 border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="mx-auto flex h-14 max-w-5xl items-center gap-4 px-4">
          <Link to="/" className="flex items-center gap-2 font-semibold tracking-tight">
            <Database className="h-5 w-5" />
            <span>DB&nbsp;Manager</span>
          </Link>

          <Separator orientation="vertical" className="mx-2 h-6" />

          <nav className="flex items-center gap-1">
            {NAV_ITEMS.map(({ to, label, icon: Icon }) => (
              <Button
                key={to}
                variant={pathname === to ? "secondary" : "ghost"}
                size="sm"
                asChild
              >
                <Link to={to}>
                  <Icon className="mr-1.5 h-4 w-4" />
                  {label}
                </Link>
              </Button>
            ))}
          </nav>
        </div>
      </header>

      {/* ── Main content ────────────────────────────────────────────────── */}
      <main className="mx-auto max-w-5xl px-4 py-8">
        <Outlet />
      </main>
    </div>
  );
}
