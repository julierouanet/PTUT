import { Package, AlertTriangle, Wrench, XCircle, Plus, AlertCircle, ClipboardList } from 'lucide-react';
import { mockEquipment, mockIssues } from '../data/mockData';
import { View } from '../App';

interface DashboardProps {
  onNavigate: (view: View) => void;
}

export function Dashboard({ onNavigate }: DashboardProps) {
  const totalEquipment = mockEquipment.length;
  const disponible = mockEquipment.filter(eq => eq.status === 'Disponible').length;
  const enUsage = mockEquipment.filter(eq => eq.status === 'En usage').length;
  const enMaintenance = mockEquipment.filter(eq => eq.status === 'En maintenance').length;
  const horsService = mockEquipment.filter(eq => eq.status === 'Hors service').length;

  const recentIssues = mockIssues.filter(issue => issue.status === 'Open' || issue.status === 'In Progress').slice(0, 5);
  const criticalAlerts = [
    ...mockEquipment.filter(eq => eq.status === 'Hors service').map(eq => ({
      type: 'Panne critique',
      message: `${eq.name} - ${eq.department}`,
      severity: 'critical' as const
    })),
    ...mockIssues.filter(issue => issue.status === 'Open').map(issue => ({
      type: 'Incident ouvert',
      message: `${issue.equipmentName} - ${issue.description.slice(0, 50)}...`,
      severity: 'warning' as const
    }))
  ].slice(0, 4);

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-gray-900 mb-2">Tableau de bord</h1>
        <p className="text-gray-600">Vue d'ensemble de la gestion des équipements</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-blue-50 p-3 rounded-lg">
              <Package className="w-6 h-6 text-blue-600" />
            </div>
          </div>
          <p className="text-gray-600 mb-1">Total Équipements</p>
          <p className="text-blue-600">{totalEquipment}</p>
        </div>

        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-green-50 p-3 rounded-lg">
              <Package className="w-6 h-6 text-green-600" />
            </div>
          </div>
          <p className="text-gray-600 mb-1">Disponibles</p>
          <p className="text-green-600">{disponible}</p>
        </div>

        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-orange-50 p-3 rounded-lg">
              <Wrench className="w-6 h-6 text-orange-600" />
            </div>
          </div>
          <p className="text-gray-600 mb-1">En Maintenance</p>
          <p className="text-orange-600">{enMaintenance}</p>
        </div>

        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-red-50 p-3 rounded-lg">
              <XCircle className="w-6 h-6 text-red-600" />
            </div>
          </div>
          <p className="text-gray-600 mb-1">Hors Service</p>
          <p className="text-red-600">{horsService}</p>
        </div>
      </div>

      {/* Status Overview */}
      <div className="bg-white p-6 rounded-lg border border-gray-200 mb-8">
        <h2 className="text-gray-900 mb-6">Statut des équipements</h2>
        <div className="space-y-4">
          <div>
            <div className="flex justify-between mb-2">
              <span className="text-gray-700">Disponible</span>
              <span className="text-gray-900">{disponible}/{totalEquipment}</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-green-500 h-2 rounded-full" 
                style={{ width: `${(disponible / totalEquipment) * 100}%` }}
              />
            </div>
          </div>
          <div>
            <div className="flex justify-between mb-2">
              <span className="text-gray-700">En usage</span>
              <span className="text-gray-900">{enUsage}/{totalEquipment}</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-blue-500 h-2 rounded-full" 
                style={{ width: `${(enUsage / totalEquipment) * 100}%` }}
              />
            </div>
          </div>
          <div>
            <div className="flex justify-between mb-2">
              <span className="text-gray-700">En maintenance</span>
              <span className="text-gray-900">{enMaintenance}/{totalEquipment}</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-orange-500 h-2 rounded-full" 
                style={{ width: `${(enMaintenance / totalEquipment) * 100}%` }}
              />
            </div>
          </div>
          <div>
            <div className="flex justify-between mb-2">
              <span className="text-gray-700">Hors service</span>
              <span className="text-gray-900">{horsService}/{totalEquipment}</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-red-500 h-2 rounded-full" 
                style={{ width: `${(horsService / totalEquipment) * 100}%` }}
              />
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Recent Issues */}
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <h2 className="text-gray-900 mb-6">Derniers incidents signalés</h2>
          <div className="space-y-4">
            {recentIssues.map(issue => (
              <div key={issue.id} className="flex items-start gap-3 pb-4 border-b border-gray-100 last:border-0">
                <div className={`p-2 rounded-lg ${
                  issue.status === 'Open' ? 'bg-red-50' : 'bg-orange-50'
                }`}>
                  <AlertCircle className={`w-4 h-4 ${
                    issue.status === 'Open' ? 'text-red-600' : 'text-orange-600'
                  }`} />
                </div>
                <div className="flex-1">
                  <p className="text-gray-900">{issue.equipmentName}</p>
                  <p className="text-gray-600">{issue.description}</p>
                  <p className="text-gray-500 mt-1">{issue.createdAt}</p>
                </div>
                <span className={`px-2 py-1 rounded ${
                  issue.status === 'Open' 
                    ? 'bg-red-50 text-red-700' 
                    : 'bg-orange-50 text-orange-700'
                }`}>
                  {issue.status}
                </span>
              </div>
            ))}
          </div>
          <button 
            onClick={() => onNavigate('issue-tracking')}
            className="w-full mt-4 px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors"
          >
            Voir tous les incidents
          </button>
        </div>

        {/* Critical Alerts */}
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <h2 className="text-gray-900 mb-6">Alertes urgentes</h2>
          <div className="space-y-4">
            {criticalAlerts.map((alert, index) => (
              <div key={index} className="flex items-start gap-3 pb-4 border-b border-gray-100 last:border-0">
                <div className={`p-2 rounded-lg ${
                  alert.severity === 'critical' ? 'bg-red-50' : 'bg-orange-50'
                }`}>
                  <AlertTriangle className={`w-4 h-4 ${
                    alert.severity === 'critical' ? 'text-red-600' : 'text-orange-600'
                  }`} />
                </div>
                <div className="flex-1">
                  <p className="text-gray-900">{alert.type}</p>
                  <p className="text-gray-600">{alert.message}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="mt-8">
        <h2 className="text-gray-900 mb-4">Actions rapides</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <button 
            onClick={() => onNavigate('equipment-list')}
            className="flex items-center gap-3 p-4 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            <Plus className="w-5 h-5" />
            <span>Ajouter un équipement</span>
          </button>
          <button 
            onClick={() => onNavigate('issue-form')}
            className="flex items-center gap-3 p-4 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors"
          >
            <AlertCircle className="w-5 h-5" />
            <span>Signaler un problème</span>
          </button>
          <button 
            onClick={() => onNavigate('issue-tracking')}
            className="flex items-center gap-3 p-4 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
          >
            <ClipboardList className="w-5 h-5" />
            <span>Voir les demandes en cours</span>
          </button>
        </div>
      </div>
    </div>
  );
}
