import { ArrowLeft, MapPin, Package, FileText, Calendar, AlertCircle, Edit } from 'lucide-react';
import { mockEquipment } from '../data/mockData';
import { View } from '../App';

interface EquipmentDetailProps {
  equipmentId: string | null;
  onNavigate: (view: View) => void;
}

export function EquipmentDetail({ equipmentId, onNavigate }: EquipmentDetailProps) {
  const equipment = mockEquipment.find(eq => eq.id === equipmentId);

  if (!equipment) {
    return (
      <div className="p-8">
        <div className="bg-white p-12 rounded-lg border border-gray-200 text-center">
          <p className="text-gray-600">Équipement non trouvé</p>
          <button 
            onClick={() => onNavigate('equipment-list')}
            className="mt-4 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Retour à la liste
          </button>
        </div>
      </div>
    );
  }

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
      {/* Header */}
      <div className="mb-6">
        <button 
          onClick={() => onNavigate('equipment-list')}
          className="flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-4"
        >
          <ArrowLeft className="w-5 h-5" />
          Retour à la liste
        </button>
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-gray-900 mb-2">{equipment.name}</h1>
            <p className="text-gray-600">{equipment.department}</p>
          </div>
          <span className={`px-4 py-2 rounded-full border ${getStatusColor(equipment.status)}`}>
            {equipment.status}
          </span>
        </div>
      </div>

      {/* Main Info */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        <div className="lg:col-span-2 bg-white p-6 rounded-lg border border-gray-200">
          <h2 className="text-gray-900 mb-6">Informations générales</h2>
          <div className="grid grid-cols-2 gap-6">
            <div>
              <div className="flex items-center gap-2 mb-2">
                <Package className="w-4 h-4 text-gray-400" />
                <p className="text-gray-600">Type d'équipement</p>
              </div>
              <p className="text-gray-900">{equipment.category}</p>
            </div>
            <div>
              <div className="flex items-center gap-2 mb-2">
                <FileText className="w-4 h-4 text-gray-400" />
                <p className="text-gray-600">Numéro de série</p>
              </div>
              <p className="text-gray-900">{equipment.serialNumber}</p>
            </div>
            <div>
              <div className="flex items-center gap-2 mb-2">
                <Package className="w-4 h-4 text-gray-400" />
                <p className="text-gray-600">Fournisseur</p>
              </div>
              <p className="text-gray-900">{equipment.supplier}</p>
            </div>
            <div>
              <div className="flex items-center gap-2 mb-2">
                <MapPin className="w-4 h-4 text-gray-400" />
                <p className="text-gray-600">Emplacement</p>
              </div>
              <p className="text-gray-900">{equipment.location}</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <h2 className="text-gray-900 mb-6">Actions</h2>
          <div className="space-y-3">
            <button className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
              <Edit className="w-4 h-4" />
              Mettre à jour le statut
            </button>
            <button 
              onClick={() => onNavigate('issue-form')}
              className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors"
            >
              <AlertCircle className="w-4 h-4" />
              Signaler un problème
            </button>
          </div>
        </div>
      </div>

      {/* Maintenance History */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center gap-2 mb-6">
            <Calendar className="w-5 h-5 text-gray-700" />
            <h2 className="text-gray-900">Historique de maintenance</h2>
          </div>
          {equipment.maintenanceHistory.length > 0 ? (
            <div className="space-y-4">
              {equipment.maintenanceHistory.map((record, index) => (
                <div key={index} className="pb-4 border-b border-gray-100 last:border-0">
                  <div className="flex items-start gap-3">
                    <div className="w-2 h-2 bg-blue-600 rounded-full mt-2"></div>
                    <div className="flex-1">
                      <p className="text-gray-900">{record.intervention}</p>
                      <p className="text-gray-600 mt-1">Par {record.technician}</p>
                      <p className="text-gray-500 mt-1">{record.date}</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500">Aucun historique de maintenance</p>
          )}
        </div>

        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center gap-2 mb-6">
            <Calendar className="w-5 h-5 text-gray-700" />
            <h2 className="text-gray-900">Maintenance future planifiée</h2>
          </div>
          {equipment.futureMaintenance.length > 0 ? (
            <div className="space-y-4">
              {equipment.futureMaintenance.map((record, index) => (
                <div key={index} className="pb-4 border-b border-gray-100 last:border-0">
                  <div className="flex items-start gap-3">
                    <div className="w-2 h-2 bg-green-600 rounded-full mt-2"></div>
                    <div className="flex-1">
                      <p className="text-gray-900">{record.intervention}</p>
                      <p className="text-gray-600 mt-1">Par {record.technician}</p>
                      <p className="text-gray-500 mt-1">{record.date}</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500">Aucune maintenance planifiée</p>
          )}
        </div>
      </div>
    </div>
  );
}
