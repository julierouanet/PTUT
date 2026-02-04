import { useState } from 'react';
import { Plus, Minus, AlertTriangle, Package, Search } from 'lucide-react';
import { mockInventory, InventoryItem } from '../data/mockData';

export function InventoryModule() {
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('Tous');
  const [showAddModal, setShowAddModal] = useState(false);
  const [showRemoveModal, setShowRemoveModal] = useState(false);
  const [selectedItem, setSelectedItem] = useState<InventoryItem | null>(null);

  const categories = ['Tous', ...new Set(mockInventory.map(item => item.category))];

  const filteredInventory = mockInventory.filter(item => {
    const matchesSearch = item.name.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = categoryFilter === 'Tous' || item.category === categoryFilter;
    return matchesSearch && matchesCategory;
  });

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Normal': return 'bg-green-50 text-green-700 border-green-200';
      case 'Bas': return 'bg-orange-50 text-orange-700 border-orange-200';
      case 'Rupture': return 'bg-red-50 text-red-700 border-red-200';
      default: return 'bg-gray-50 text-gray-700 border-gray-200';
    }
  };

  const getStockPercentage = (current: number, min: number) => {
    if (current === 0) return 0;
    return Math.min(((current / (min * 2)) * 100), 100);
  };

  const lowStockItems = mockInventory.filter(item => item.status === 'Bas' || item.status === 'Rupture');

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-gray-900 mb-2">Inventaire - Consommables & Hygiène</h1>
        <p className="text-gray-600">Gestion des stocks et réapprovisionnement</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-blue-50 p-3 rounded-lg">
              <Package className="w-6 h-6 text-blue-600" />
            </div>
          </div>
          <p className="text-gray-600 mb-1">Total articles</p>
          <p className="text-blue-600">{mockInventory.length}</p>
        </div>

        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-green-50 p-3 rounded-lg">
              <Package className="w-6 h-6 text-green-600" />
            </div>
          </div>
          <p className="text-gray-600 mb-1">Stock normal</p>
          <p className="text-green-600">
            {mockInventory.filter(i => i.status === 'Normal').length}
          </p>
        </div>

        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-orange-50 p-3 rounded-lg">
              <AlertTriangle className="w-6 h-6 text-orange-600" />
            </div>
          </div>
          <p className="text-gray-600 mb-1">Stock bas</p>
          <p className="text-orange-600">
            {mockInventory.filter(i => i.status === 'Bas').length}
          </p>
        </div>

        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-red-50 p-3 rounded-lg">
              <AlertTriangle className="w-6 h-6 text-red-600" />
            </div>
          </div>
          <p className="text-gray-600 mb-1">Rupture de stock</p>
          <p className="text-red-600">
            {mockInventory.filter(i => i.status === 'Rupture').length}
          </p>
        </div>
      </div>

      {/* Alerts */}
      {lowStockItems.length > 0 && (
        <div className="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-6">
          <div className="flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-orange-600 mt-0.5" />
            <div>
              <p className="text-orange-900 mb-2">Alertes de réapprovisionnement</p>
              <div className="space-y-1">
                {lowStockItems.map(item => (
                  <p key={item.id} className="text-orange-800">
                    • {item.name} - {item.status === 'Rupture' ? 'RUPTURE DE STOCK' : `Stock bas (${item.currentStock} ${item.unit})`}
                  </p>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Search and Filters */}
      <div className="bg-white p-6 rounded-lg border border-gray-200 mb-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="md:col-span-2 relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              placeholder="Rechercher un article..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 appearance-none bg-white"
          >
            {categories.map(cat => (
              <option key={cat} value={cat}>{cat}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Inventory Table */}
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-left text-gray-700">Article</th>
                <th className="px-6 py-3 text-left text-gray-700">Catégorie</th>
                <th className="px-6 py-3 text-left text-gray-700">Stock actuel</th>
                <th className="px-6 py-3 text-left text-gray-700">Stock minimum</th>
                <th className="px-6 py-3 text-left text-gray-700">Niveau</th>
                <th className="px-6 py-3 text-left text-gray-700">Statut</th>
                <th className="px-6 py-3 text-left text-gray-700">Dernier réappro.</th>
                <th className="px-6 py-3 text-left text-gray-700">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredInventory.map(item => (
                <tr key={item.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 text-gray-900">{item.name}</td>
                  <td className="px-6 py-4">
                    <span className="px-2 py-1 bg-gray-100 text-gray-700 rounded">
                      {item.category}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-gray-900">
                    {item.currentStock} {item.unit}
                  </td>
                  <td className="px-6 py-4 text-gray-600">
                    {item.minStock} {item.unit}
                  </td>
                  <td className="px-6 py-4">
                    <div className="w-full bg-gray-200 rounded-full h-2">
                      <div 
                        className={`h-2 rounded-full ${
                          item.status === 'Rupture' 
                            ? 'bg-red-500' 
                            : item.status === 'Bas'
                            ? 'bg-orange-500'
                            : 'bg-green-500'
                        }`}
                        style={{ width: `${getStockPercentage(item.currentStock, item.minStock)}%` }}
                      />
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-3 py-1 rounded-full border ${getStatusColor(item.status)}`}>
                      {item.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-gray-600">{item.lastRestocked}</td>
                  <td className="px-6 py-4">
                    <div className="flex gap-2">
                      <button
                        onClick={() => {
                          setSelectedItem(item);
                          setShowAddModal(true);
                        }}
                        className="p-2 bg-green-600 text-white rounded hover:bg-green-700 transition-colors"
                        title="Ajouter une entrée"
                      >
                        <Plus className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => {
                          setSelectedItem(item);
                          setShowRemoveModal(true);
                        }}
                        className="p-2 bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
                        title="Enregistrer une sortie"
                      >
                        <Minus className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Stock Modal */}
      {showAddModal && selectedItem && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white p-6 rounded-lg max-w-md w-full mx-4">
            <h3 className="text-gray-900 mb-4">Ajouter une entrée - {selectedItem.name}</h3>
            <div className="mb-4">
              <label className="block text-gray-700 mb-2">Quantité à ajouter</label>
              <input
                type="number"
                min="1"
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder={`Nombre de ${selectedItem.unit}`}
              />
            </div>
            <div className="mb-6">
              <label className="block text-gray-700 mb-2">Note (optionnel)</label>
              <textarea
                rows={3}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
                placeholder="Ex: Réapprovisionnement mensuel"
              />
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowAddModal(false)}
                className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
              >
                Confirmer l'entrée
              </button>
              <button
                onClick={() => setShowAddModal(false)}
                className="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Annuler
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Remove Stock Modal */}
      {showRemoveModal && selectedItem && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white p-6 rounded-lg max-w-md w-full mx-4">
            <h3 className="text-gray-900 mb-4">Enregistrer une sortie - {selectedItem.name}</h3>
            <div className="mb-4">
              <label className="block text-gray-700 mb-2">Quantité à retirer</label>
              <input
                type="number"
                min="1"
                max={selectedItem.currentStock}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder={`Nombre de ${selectedItem.unit} (max: ${selectedItem.currentStock})`}
              />
            </div>
            <div className="mb-6">
              <label className="block text-gray-700 mb-2">Destination/Raison</label>
              <input
                type="text"
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Ex: Chirurgie, Urgences..."
              />
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowRemoveModal(false)}
                className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
              >
                Confirmer la sortie
              </button>
              <button
                onClick={() => setShowRemoveModal(false)}
                className="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Annuler
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
