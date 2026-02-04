import { useState } from 'react';
import { Upload, AlertCircle, Check } from 'lucide-react';
import { mockEquipment } from '../data/mockData';
import { View } from '../App';

interface IssueFormProps {
  onNavigate: (view: View) => void;
}

export function IssueForm({ onNavigate }: IssueFormProps) {
  const [selectedEquipment, setSelectedEquipment] = useState('');
  const [problemType, setProblemType] = useState('');
  const [description, setDescription] = useState('');
  const [submitted, setSubmitted] = useState(false);

  const currentUser = 'Dr. Konaté';
  const currentDepartment = 'Médecine Générale';
  const currentTimestamp = new Date().toLocaleString('fr-FR', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitted(true);
    setTimeout(() => {
      onNavigate('issue-tracking');
    }, 2000);
  };

  if (submitted) {
    return (
      <div className="p-8">
        <div className="max-w-2xl mx-auto">
          <div className="bg-white p-12 rounded-lg border border-gray-200 text-center">
            <div className="w-16 h-16 bg-green-50 rounded-full flex items-center justify-center mx-auto mb-4">
              <Check className="w-8 h-8 text-green-600" />
            </div>
            <h2 className="text-gray-900 mb-2">Problème signalé avec succès</h2>
            <p className="text-gray-600 mb-6">
              Un ticket d'incident a été créé et assigné à un technicien.
            </p>
            <button 
              onClick={() => onNavigate('issue-tracking')}
              className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Voir les tickets
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8">
      <div className="max-w-3xl mx-auto">
        <div className="mb-8">
          <h1 className="text-gray-900 mb-2">Signaler un problème</h1>
          <p className="text-gray-600">Créer un nouveau ticket d'incident pour un équipement</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-white p-8 rounded-lg border border-gray-200">
          {/* Auto-filled Information */}
          <div className="bg-blue-50 p-4 rounded-lg mb-6">
            <p className="text-blue-900 mb-3">Informations automatiques</p>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <p className="text-blue-700">Rapporteur</p>
                <p className="text-blue-900">{currentUser}</p>
              </div>
              <div>
                <p className="text-blue-700">Département</p>
                <p className="text-blue-900">{currentDepartment}</p>
              </div>
              <div>
                <p className="text-blue-700">Date & Heure</p>
                <p className="text-blue-900">{currentTimestamp}</p>
              </div>
            </div>
          </div>

          {/* Equipment Selection */}
          <div className="mb-6">
            <label className="block text-gray-700 mb-2">
              Sélection de l'équipement <span className="text-red-500">*</span>
            </label>
            <select
              required
              value={selectedEquipment}
              onChange={(e) => setSelectedEquipment(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">-- Sélectionner un équipement --</option>
              {mockEquipment.map(eq => (
                <option key={eq.id} value={eq.id}>
                  {eq.name} - {eq.department} ({eq.serialNumber})
                </option>
              ))}
            </select>
          </div>

          {/* Problem Type */}
          <div className="mb-6">
            <label className="block text-gray-700 mb-2">
              Type de problème <span className="text-red-500">*</span>
            </label>
            <select
              required
              value={problemType}
              onChange={(e) => setProblemType(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">-- Sélectionner un type --</option>
              <option value="ICT">ICT - Informatique et Télécommunications</option>
              <option value="Biomédical">Biomédical - Équipement médical</option>
              <option value="Électrique">Électrique - Installation électrique</option>
              <option value="Mécanique">Mécanique - Problème mécanique</option>
              <option value="Autre">Autre</option>
            </select>
          </div>

          {/* Description */}
          <div className="mb-6">
            <label className="block text-gray-700 mb-2">
              Description du problème <span className="text-red-500">*</span>
            </label>
            <textarea
              required
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={6}
              placeholder="Décrivez le problème en détail..."
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
            />
            <p className="text-gray-500 mt-2">
              Soyez aussi précis que possible : symptômes, messages d'erreur, circonstances...
            </p>
          </div>

          {/* Photo Upload */}
          <div className="mb-8">
            <label className="block text-gray-700 mb-2">
              Upload de photo <span className="text-gray-500">(optionnel)</span>
            </label>
            <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-blue-500 transition-colors cursor-pointer">
              <Upload className="w-8 h-8 text-gray-400 mx-auto mb-3" />
              <p className="text-gray-600 mb-1">Cliquez pour télécharger une photo</p>
              <p className="text-gray-500">PNG, JPG jusqu'à 10MB</p>
              <input 
                type="file" 
                accept="image/*" 
                className="hidden" 
              />
            </div>
          </div>

          {/* Actions */}
          <div className="flex gap-4">
            <button
              type="submit"
              className="flex-1 flex items-center justify-center gap-2 px-6 py-3 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors"
            >
              <AlertCircle className="w-5 h-5" />
              Soumettre le signalement
            </button>
            <button
              type="button"
              onClick={() => onNavigate('dashboard')}
              className="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
            >
              Annuler
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
