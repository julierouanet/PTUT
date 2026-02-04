import { useState } from 'react';
import { Dashboard } from './components/Dashboard';
import { EquipmentList } from './components/EquipmentList';
import { EquipmentDetail } from './components/EquipmentDetail';
import { IssueForm } from './components/IssueForm';
import { IssueTracking } from './components/IssueTracking';
import { TechnicianUpdate } from './components/TechnicianUpdate';
import { InventoryModule } from './components/InventoryModule';
import { ReportsPage } from './components/ReportsPage';
import { 
  LayoutDashboard, 
  Package, 
  AlertCircle, 
  ClipboardList, 
  Wrench, 
  Archive, 
  FileText 
} from 'lucide-react';

export type View = 
  | 'dashboard' 
  | 'equipment-list' 
  | 'equipment-detail' 
  | 'issue-form' 
  | 'issue-tracking' 
  | 'technician-update' 
  | 'inventory' 
  | 'reports';

export interface Equipment {
  id: string;
  name: string;
  department: string;
  category: string;
  serialNumber: string;
  status: 'Disponible' | 'En usage' | 'En maintenance' | 'Hors service';
  supplier: string;
  location: string;
  maintenanceHistory: MaintenanceRecord[];
  futureMaintenance: MaintenanceRecord[];
}

export interface MaintenanceRecord {
  date: string;
  intervention: string;
  technician: string;
}

export interface Issue {
  id: string;
  equipmentId: string;
  equipmentName: string;
  department: string;
  type: string;
  description: string;
  reporter: string;
  createdAt: string;
  status: 'Open' | 'In Progress' | 'Resolved';
  assignedTechnician?: string;
  diagnosis?: string;
  actions?: string;
  partsReplaced?: string;
}

function App() {
  const [currentView, setCurrentView] = useState<View>('dashboard');
  const [selectedEquipmentId, setSelectedEquipmentId] = useState<string | null>(null);
  const [selectedIssueId, setSelectedIssueId] = useState<string | null>(null);

  const handleViewChange = (view: View, equipmentId?: string, issueId?: string) => {
    setCurrentView(view);
    if (equipmentId) setSelectedEquipmentId(equipmentId);
    if (issueId) setSelectedIssueId(issueId);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Sidebar Navigation */}
      <div className="flex">
        <aside className="w-64 bg-white border-r border-gray-200 min-h-screen">
          <div className="p-6">
            <h1 className="text-blue-600">Gestion des Équipements</h1>
          </div>
          <nav className="px-4 space-y-1">
            <button
              onClick={() => setCurrentView('dashboard')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                currentView === 'dashboard' 
                  ? 'bg-blue-50 text-blue-600' 
                  : 'text-gray-700 hover:bg-gray-50'
              }`}
            >
              <LayoutDashboard className="w-5 h-5" />
              <span>Tableau de bord</span>
            </button>
            <button
              onClick={() => setCurrentView('equipment-list')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                currentView === 'equipment-list' 
                  ? 'bg-blue-50 text-blue-600' 
                  : 'text-gray-700 hover:bg-gray-50'
              }`}
            >
              <Package className="w-5 h-5" />
              <span>Liste des équipements</span>
            </button>
            <button
              onClick={() => setCurrentView('issue-tracking')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                currentView === 'issue-tracking' 
                  ? 'bg-blue-50 text-blue-600' 
                  : 'text-gray-700 hover:bg-gray-50'
              }`}
            >
              <AlertCircle className="w-5 h-5" />
              <span>Suivi des incidents</span>
            </button>
            <button
              onClick={() => setCurrentView('issue-form')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                currentView === 'issue-form' 
                  ? 'bg-blue-50 text-blue-600' 
                  : 'text-gray-700 hover:bg-gray-50'
              }`}
            >
              <ClipboardList className="w-5 h-5" />
              <span>Signaler un problème</span>
            </button>
            <button
              onClick={() => setCurrentView('technician-update')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                currentView === 'technician-update' 
                  ? 'bg-blue-50 text-blue-600' 
                  : 'text-gray-700 hover:bg-gray-50'
              }`}
            >
              <Wrench className="w-5 h-5" />
              <span>Mise à jour technicien</span>
            </button>
            <button
              onClick={() => setCurrentView('inventory')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                currentView === 'inventory' 
                  ? 'bg-blue-50 text-blue-600' 
                  : 'text-gray-700 hover:bg-gray-50'
              }`}
            >
              <Archive className="w-5 h-5" />
              <span>Inventaire</span>
            </button>
            <button
              onClick={() => setCurrentView('reports')}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                currentView === 'reports' 
                  ? 'bg-blue-50 text-blue-600' 
                  : 'text-gray-700 hover:bg-gray-50'
              }`}
            >
              <FileText className="w-5 h-5" />
              <span>Rapports</span>
            </button>
          </nav>
        </aside>

        {/* Main Content */}
        <main className="flex-1">
          {currentView === 'dashboard' && <Dashboard onNavigate={handleViewChange} />}
          {currentView === 'equipment-list' && <EquipmentList onNavigate={handleViewChange} />}
          {currentView === 'equipment-detail' && (
            <EquipmentDetail equipmentId={selectedEquipmentId} onNavigate={handleViewChange} />
          )}
          {currentView === 'issue-form' && <IssueForm onNavigate={handleViewChange} />}
          {currentView === 'issue-tracking' && <IssueTracking onNavigate={handleViewChange} />}
          {currentView === 'technician-update' && (
            <TechnicianUpdate issueId={selectedIssueId} onNavigate={handleViewChange} />
          )}
          {currentView === 'inventory' && <InventoryModule />}
          {currentView === 'reports' && <ReportsPage />}
        </main>
      </div>
    </div>
  );
}

export default App;
