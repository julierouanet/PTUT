import { useState } from 'react';
import { FileDown, Calendar, Filter } from 'lucide-react';

export function ReportsPage() {
  const [reportType, setReportType] = useState('equipment-list');
  const [department, setDepartment] = useState('Tous');
  const [startDate, setStartDate] = useState('2024-01-01');
  const [endDate, setEndDate] = useState('2024-12-31');

  const departments = ['Tous', 'Radiologie', 'Réanimation', 'IT', 'Infrastructure', 'Stérilisation', 'Urgences'];

  const reportTypes = [
    {
      id: 'equipment-list',
      title: 'Liste des équipements par département',
      description: 'Export complet de tous les équipements avec leurs informations détaillées',
      icon: '📋'
    },
    {
      id: 'maintenance-history',
      title: 'Historique de maintenance',
      description: 'Toutes les interventions de maintenance effectuées sur la période',
      icon: '🔧'
    },
    {
      id: 'failure-analysis',
      title: 'Analyse des pannes',
      description: 'Statistiques sur les pannes et incidents par équipement et département',
      icon: '📊'
    },
    {
      id: 'maintenance-costs',
      title: 'Coûts de maintenance',
      description: 'Rapport financier des coûts liés à la maintenance et aux réparations',
      icon: '💰'
    },
    {
      id: 'inventory-status',
      title: 'État des stocks',
      description: 'Rapport sur les niveaux de stock des consommables et produits d\'hygiène',
      icon: '📦'
    },
    {
      id: 'technician-performance',
      title: 'Performance des techniciens',
      description: 'Statistiques sur les interventions réalisées par technicien',
      icon: '👨‍🔧'
    }
  ];

  const handleExport = (format: 'pdf' | 'excel') => {
    alert(`Export ${format.toUpperCase()} du rapport "${reportTypes.find(r => r.id === reportType)?.title}" en cours...`);
  };

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-gray-900 mb-2">Génération de rapports</h1>
        <p className="text-gray-600">Exportez des rapports détaillés sur la gestion des équipements</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Report Configuration */}
        <div className="lg:col-span-2 space-y-6">
          {/* Report Type Selection */}
          <div className="bg-white p-6 rounded-lg border border-gray-200">
            <h2 className="text-gray-900 mb-4">Type de rapport</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {reportTypes.map(report => (
                <button
                  key={report.id}
                  onClick={() => setReportType(report.id)}
                  className={`p-4 rounded-lg border-2 text-left transition-all ${
                    reportType === report.id
                      ? 'border-blue-600 bg-blue-50'
                      : 'border-gray-200 hover:border-gray-300'
                  }`}
                >
                  <div className="flex items-start gap-3">
                    <span className="text-2xl">{report.icon}</span>
                    <div className="flex-1">
                      <p className={`mb-1 ${
                        reportType === report.id ? 'text-blue-900' : 'text-gray-900'
                      }`}>
                        {report.title}
                      </p>
                      <p className={`${
                        reportType === report.id ? 'text-blue-700' : 'text-gray-600'
                      }`}>
                        {report.description}
                      </p>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* Filters */}
          <div className="bg-white p-6 rounded-lg border border-gray-200">
            <div className="flex items-center gap-2 mb-6">
              <Filter className="w-5 h-5 text-gray-700" />
              <h2 className="text-gray-900">Filtres et paramètres</h2>
            </div>
            <div className="space-y-4">
              {/* Department Filter */}
              <div>
                <label className="block text-gray-700 mb-2">Département</label>
                <select
                  value={department}
                  onChange={(e) => setDepartment(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 appearance-none bg-white"
                >
                  {departments.map(dept => (
                    <option key={dept} value={dept}>{dept}</option>
                  ))}
                </select>
              </div>

              {/* Date Range */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-gray-700 mb-2">Date de début</label>
                  <div className="relative">
                    <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                    <input
                      type="date"
                      value={startDate}
                      onChange={(e) => setStartDate(e.target.value)}
                      className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-gray-700 mb-2">Date de fin</label>
                  <div className="relative">
                    <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                    <input
                      type="date"
                      value={endDate}
                      onChange={(e) => setEndDate(e.target.value)}
                      className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                </div>
              </div>

              {/* Additional Options */}
              <div className="border-t border-gray-200 pt-4">
                <p className="text-gray-700 mb-3">Options supplémentaires</p>
                <div className="space-y-2">
                  <label className="flex items-center gap-2">
                    <input type="checkbox" className="rounded" defaultChecked />
                    <span className="text-gray-700">Inclure les graphiques</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" className="rounded" defaultChecked />
                    <span className="text-gray-700">Inclure les photos des équipements</span>
                  </label>
                  <label className="flex items-center gap-2">
                    <input type="checkbox" className="rounded" />
                    <span className="text-gray-700">Afficher uniquement les anomalies</span>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Preview & Export */}
        <div className="space-y-6">
          {/* Report Summary */}
          <div className="bg-white p-6 rounded-lg border border-gray-200">
            <h2 className="text-gray-900 mb-4">Aperçu du rapport</h2>
            <div className="space-y-3">
              <div>
                <p className="text-gray-600">Type</p>
                <p className="text-gray-900">
                  {reportTypes.find(r => r.id === reportType)?.title}
                </p>
              </div>
              <div>
                <p className="text-gray-600">Département</p>
                <p className="text-gray-900">{department}</p>
              </div>
              <div>
                <p className="text-gray-600">Période</p>
                <p className="text-gray-900">
                  {new Date(startDate).toLocaleDateString('fr-FR')} - {new Date(endDate).toLocaleDateString('fr-FR')}
                </p>
              </div>
              <div className="pt-3 border-t border-gray-200">
                <p className="text-gray-600">Données estimées</p>
                <p className="text-gray-900">~125 enregistrements</p>
              </div>
            </div>
          </div>

          {/* Export Buttons */}
          <div className="bg-white p-6 rounded-lg border border-gray-200">
            <h2 className="text-gray-900 mb-4">Exporter le rapport</h2>
            <div className="space-y-3">
              <button
                onClick={() => handleExport('pdf')}
                className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
              >
                <FileDown className="w-5 h-5" />
                Télécharger en PDF
              </button>
              <button
                onClick={() => handleExport('excel')}
                className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
              >
                <FileDown className="w-5 h-5" />
                Télécharger en Excel
              </button>
            </div>
          </div>

          {/* Quick Stats */}
          <div className="bg-gradient-to-br from-blue-50 to-blue-100 p-6 rounded-lg border border-blue-200">
            <h3 className="text-blue-900 mb-4">Statistiques rapides</h3>
            <div className="space-y-3">
              <div className="flex justify-between">
                <span className="text-blue-800">Total équipements</span>
                <span className="text-blue-900">8</span>
              </div>
              <div className="flex justify-between">
                <span className="text-blue-800">Incidents ce mois</span>
                <span className="text-blue-900">6</span>
              </div>
              <div className="flex justify-between">
                <span className="text-blue-800">Maintenances planifiées</span>
                <span className="text-blue-900">12</span>
              </div>
              <div className="flex justify-between">
                <span className="text-blue-800">Taux de disponibilité</span>
                <span className="text-blue-900">87.5%</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
