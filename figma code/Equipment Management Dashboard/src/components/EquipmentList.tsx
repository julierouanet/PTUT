import { useState } from 'react';
import { Search, Filter, Eye, AlertCircle } from 'lucide-react';
import { mockEquipment } from '../data/mockData';
import { View } from '../App';

interface EquipmentListProps {
  onNavigate: (view: View, equipmentId?: string) => void;
}

export function EquipmentList({ onNavigate }: EquipmentListProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [departmentFilter, setDepartmentFilter] = useState('Tous');
  const [statusFilter, setStatusFilter] = useState('Tous');
  const [categoryFilter, setCategoryFilter] = useState('Tous');

  const departments = ['Tous', ...new Set(mockEquipment.map(eq => eq.department))];
  const statuses = ['Tous', 'Disponible', 'En usage', 'En maintenance', 'Hors service'];
  const categories = ['Tous', ...new Set(mockEquipment.map(eq => eq.category))];

  const filteredEquipment = mockEquipment.filter(eq => {
    const matchesSearch = eq.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         eq.serialNumber.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesDepartment = departmentFilter === 'Tous' || eq.department === departmentFilter;
    const matchesStatus = statusFilter === 'Tous' || eq.status === statusFilter;
    const matchesCategory = categoryFilter === 'Tous' || eq.category === categoryFilter;
    
    return matchesSearch && matchesDepartment && matchesStatus && matchesCategory;
  });

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Disponible': return 'bg-green-50 text-green-700 border-green-200';
      case 'En usage': return 'bg-blue-50 text-blue-700 border-blue-200';
      case 'En maintenance': return 'bg-orange-50 text-orange-700 border-orange-200';
      case 'Hors service': return 'bg-red-50 text-red-700 border-red-200';
      default: return 'bg-gray-50 text-gray-700 border-gray-200';
    }
  };

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-gray-900 mb-2">Liste des équipements</h1>
        <p className="text-gray-600">Gestion et suivi de tous les équipements</p>
      </div>

      {/* Search and Filters */}
      <div className="bg-white p-6 rounded-lg border border-gray-200 mb-6">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {/* Search */}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              placeholder="Rechercher..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Department Filter */}
          <div className="relative">
            <Filter className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <select
              value={departmentFilter}
              onChange={(e) => setDepartmentFilter(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 appearance-none bg-white"
            >
              {departments.map(dept => (
                <option key={dept} value={dept}>{dept}</option>
              ))}
            </select>
          </div>

          {/* Status Filter */}
          <div className="relative">
            <Filter className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 appearance-none bg-white"
            >
              {statuses.map(status => (
                <option key={status} value={status}>{status}</option>
              ))}
            </select>
          </div>

          {/* Category Filter */}
          <div className="relative">
            <Filter className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 appearance-none bg-white"
            >
              {categories.map(category => (
                <option key={category} value={category}>{category}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="mt-4 flex items-center gap-2 text-gray-600">
          <p>{filteredEquipment.length} équipement(s) trouvé(s)</p>
        </div>
      </div>

      {/* Equipment Table */}
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-left text-gray-700">Nom de l'équipement</th>
                <th className="px-6 py-3 text-left text-gray-700">Département</th>
                <th className="px-6 py-3 text-left text-gray-700">Catégorie</th>
                <th className="px-6 py-3 text-left text-gray-700">Numéro de série</th>
                <th className="px-6 py-3 text-left text-gray-700">Statut</th>
                <th className="px-6 py-3 text-left text-gray-700">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredEquipment.map(equipment => (
                <tr key={equipment.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 text-gray-900">{equipment.name}</td>
                  <td className="px-6 py-4 text-gray-600">{equipment.department}</td>
                  <td className="px-6 py-4">
                    <span className="px-2 py-1 bg-gray-100 text-gray-700 rounded">
                      {equipment.category}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-gray-600">{equipment.serialNumber}</td>
                  <td className="px-6 py-4">
                    <span className={`px-3 py-1 rounded-full border ${getStatusColor(equipment.status)}`}>
                      {equipment.status}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex gap-2">
                      <button
                        onClick={() => onNavigate('equipment-detail', equipment.id)}
                        className="px-3 py-1 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors flex items-center gap-2"
                      >
                        <Eye className="w-4 h-4" />
                        Détails
                      </button>
                      <button
                        onClick={() => onNavigate('issue-form', equipment.id)}
                        className="px-3 py-1 bg-orange-600 text-white rounded hover:bg-orange-700 transition-colors flex items-center gap-2"
                      >
                        <AlertCircle className="w-4 h-4" />
                        Signaler
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
