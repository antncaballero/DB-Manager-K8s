import { BrowserRouter, Route, Routes } from "react-router-dom";
import { Toaster } from "@/components/ui/sonner";
import Layout from "@/components/layout/Layout";
import DashboardPage from "@/pages/DashboardPage";
import DeployPage from "@/pages/DeployPage";
import WakePage from "@/pages/WakePage";

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<DashboardPage />} />
          <Route path="deploy" element={<DeployPage />} />
          <Route path="wake" element={<WakePage />} />
        </Route>
      </Routes>
      <Toaster richColors position="bottom-right" />
    </BrowserRouter>
  );
}

export default App;
