import { useState } from 'react';
import { ArrowLeft, Check, AlertCircle } from 'lucide-react';
import { mockIssues } from '../data/mockData';
import { View } from '../App';

interface TechnicianUpdateProps {
  issueId: string | null;
  onNavigate: (view: View) => void;
}

export function TechnicianUpdate({ issueId, onNavigate }: TechnicianUpdateProps) {
  const issue = mockIssues.find(iss => iss.id === issueId);
  
  const [diagnosis, setDiagnosis] = useState(issue?.diagnosis || '');
  const [actions, setActions] = useState(issue?.actions || '');
  const [partsReplaced, setPartsReplaced] = useState(issue?.partsReplaced || '');
  const [status, setStatus] = useState<'Diagnostiqué' | 'En cours' | 'Réparé' | 'Testé'>('Diagnostiqué');
  const [showSuccess, setShowSuccess] = useState(false);

  if (!issue) {
    return (
      <div className="p-8">
        <div className="bg-white p-12 rounded-lg border border-gray-200 text-center">
          <p className="text-gray-600">Ticket non trouvé</p>
          <button 
            onClick={() => onNavigate('issue-tracking')}
            className="mt-4 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Retour aux tickets
          </button>
        </div>
      </div>
    );
  }

  const handleMarkAsResolved = () => {
    setShowSuccess(true);
    setTimeout(() => {
      onNavigate('issue-tracking');
    }, 2000);
  };

  if (showSuccess) {
    return (
      <div className="p-8">
        <div className="max-w-2xl mx-auto">
          <div className="bg-white p-12 rounded-lg border border-gray-200 text-center">
            <div className="w-16 h-16 bg-green-50 rounded-full flex items-center justify-center mx-auto mb-4">
              <Check className="w-8 h-8 text-green-600" />
            </div>
            <h2 className="text-gray-900 mb-2">Ticket marqué comme résolu</h2>
            <p className="text-gray-600 mb-6">
              Les informations ont été enregistrées avec succès.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8">
      <div className="max-w-4xl mx-auto">
        <div className="mb-6">
          <button 
            onClick={() => onNavigate('issue-tracking')}
            className="flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-4"
          >
            <ArrowLeft className="w-5 h-5" />
            Retour aux tickets
          </button>
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-gray-900 mb-2">Mise à jour du ticket {issue.id}</h1>
              <p className="text-gray-600">{issue.equipmentName}</p>
            </div>
            <span className={`px-4 py-2 rounded ${
              issue.status === 'Open' 
                ? 'bg-red-50 text-red-700' 
                : issue.status === 'In Progress'
                ? 'bg-orange-50 text-orange-700'
                : 'bg-green-50 text-green-700'
            }`}>
              {issue.status}
            </span>
          </div>
        </div>

        {/* Issue Details */}
        <div className="bg-white p-6 rounded-lg border border-gray-200 mb-6">
          <h2 className="text-gray-900 mb-4">Détails du problème</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
            <div>
              <p className="text-gray-600">Département</p>
              <p className="text-gray-900">{issue.department}</p>
            </div>
            <div>
              <p className="text-gray-600">Type</p>
              <p className="text-gray-900">{issue.type}</p>
            </div>
            <div>
              <p className="text-gray-600">Rapporteur</p>
              <p className="text-gray-900">{issue.reporter}</p>
            </div>
            <div>
              <p className="text-gray-600">Date de création</p>
              <p className="text-gray-900">{issue.createdAt}</p>
            </div>
          </div>
          <div>
            <p className="text-gray-600 mb-2">Description</p>
            <p className="text-gray-900">{issue.description}</p>
          </div>
        </div>

        {/* Update Form */}
        <div className="bg-white p-6 rounded-lg border border-gray-200 mb-6">
          <h2 className="text-gray-900 mb-6">Intervention du technicien</h2>
          
          {/* Diagnosis */}
          <div className="mb-6">
            <label className="block text-gray-700 mb-2">
              Diagnostic
            </label>
            <textarea
              value={diagnosis}
              onChange={(e) => setDiagnosis(e.target.value)}
              rows={4}
              placeholder="Décrivez le diagnostic du problème..."
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
            />
          </div>

          {/* Actions Performed */}
          <div className="mb-6">
            <label className="block text-gray-700 mb-2">
              Actions réalisées
            </label>
            <textarea
              value={actions}
              onChange={(e) => setActions(e.target.value)}
              rows={4}
              placeholder="Décrivez les actions effectuées..."
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
            />
          </div>

          {/* Parts Replaced */}
          <div className="mb-6">
            <label className="block text-gray-700 mb-2">
              Pièces changées
            </label>
            <input
              type="text"
              value={partsReplaced}
              onChange={(e) => setPartsReplaced(e.target.value)}
              placeholder="Ex: Capteur O2, Batterie, etc."
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Status Update */}
          <div className="mb-6">
            <label className="block text-gray-700 mb-2">
              Mise à jour du statut
            </label>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <button
                onClick={() => setStatus('Diagnostiqué')}
                className={`p-4 rounded-lg border-2 transition-all ${
                  status === 'Diagnostiqué'
                    ? 'border-blue-600 bg-blue-50'
                    : 'border-gray-200 hover:border-gray-300'
                }`}
              >
                <div className="flex items-center justify-center mb-2">
                  <AlertCircle className={`w-6 h-6 ${
                    status === 'Diagnostiqué' ? 'text-blue-600' : 'text-gray-400'
                  }`} />
                </div>
                <p className={`text-center ${
                  status === 'Diagnostiqué' ? 'text-blue-900' : 'text-gray-700'
                }`}>
                  Diagnostiqué
                </p>
              </button>

              <button
                onClick={() => setStatus('En cours')}
                className={`p-4 rounded-lg border-2 transition-all ${
                  status === 'En cours'
                    ? 'border-orange-600 bg-orange-50'
                    : 'border-gray-200 hover:border-gray-300'
                }`}
              >
                <div className="flex items-center justify-center mb-2">
                  <AlertCircle className={`w-6 h-6 ${
                    status === 'En cours' ? 'text-orange-600' : 'text-gray-400'
                  }`} />
                </div>
                <p className={`text-center ${
                  status === 'En cours' ? 'text-orange-900' : 'text-gray-700'
                }`}>
                  En cours
                </p>
              </button>

              <button
                onClick={() => setStatus('Réparé')}
                className={`p-4 rounded-lg border-2 transition-all ${
                  status === 'Réparé'
                    ? 'border-green-600 bg-green-50'
                    : 'border-gray-200 hover:border-gray-300'
                }`}
              >
                <div className="flex items-center justify-center mb-2">
                  <Check className={`w-6 h-6 ${
                    status === 'Réparé' ? 'text-green-600' : 'text-gray-400'
                  }`} />
                </div>
                <p className={`text-center ${
                  status === 'Réparé' ? 'text-green-900' : 'text-gray-700'
                }`}>
                  Réparé
                </p>
              </button>

              <button
                onClick={() => setStatus('Testé')}
                className={`p-4 rounded-lg border-2 transition-all ${
                  status === 'Testé'
                    ? 'border-green-600 bg-green-50'
                    : 'border-gray-200 hover:border-gray-300'
                }`}
              >
                <div className="flex items-center justify-center mb-2">
                  <Check className={`w-6 h-6 ${
                    status === 'Testé' ? 'text-green-600' : 'text-gray-400'
                  }`} />
                </div>
                <p className={`text-center ${
                  status === 'Testé' ? 'text-green-900' : 'text-gray-700'
                }`}>
                  Testé
                </p>
              </button>
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-4">
          <button
            onClick={handleMarkAsResolved}
            className="flex-1 flex items-center justify-center gap-2 px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
          >
            <Check className="w-5 h-5" />
            Marquer comme résolu
          </button>
          <button
            className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Enregistrer les modifications
          </button>
          <button
            onClick={() => onNavigate('issue-tracking')}
            className="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Annuler
          </button>
        </div>
      </div>
    </div>
  );
}
