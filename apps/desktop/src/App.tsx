import { Editor } from "./components/Editor";
import { ProofSidebar } from "./components/ProofSidebar";
import { StatusBar } from "./components/StatusBar";

export default function App() {
  return (
    <div className="flex flex-col h-screen">
      <div className="flex flex-1 overflow-hidden">
        <div className="flex-1 overflow-y-auto" style={{ background: "var(--bg-primary)" }}>
          <Editor />
        </div>
        <ProofSidebar />
      </div>
      <StatusBar />
    </div>
  );
}
