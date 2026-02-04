import { useState } from 'react';
import { Eye, Clock, CheckCircle, AlertCircle } from 'lucide-react';
import { mockIssues } from '../data/mockData';
import { View } from '../App';

interface IssueTrackingProps {
  onNavigate: (view: View, equipmentId?: string, issueId?: string) => void;
}

export function IssueTracking({ onNavigate }: IssueTrackingProps) {
  const [activeTab, setActiveTab] = useState<'Open' | 'In Progress' | 'Resolved'>('Open');

  const openIssues = mockIssues.filter(issue => issue.status === 'Open');
  const inProgressIssues = mockIssues.filter(issue => issue.status === 'In Progress');
  const resolvedIssues = mockIssues.filter(issue => issue.status === 'Resolved');

  const getIssuesForTab = () => {
    switch (activeTab) {
      case 'Open': return openIssues;
      case 'In Progress': return inProgressIssues;
      case 'Resolved': return resolvedIssues;
    }
  };

  const currentIssues = getIssuesForTab();

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-gray-900 mb-2">Suivi des incidents</h1>
        <p className="text-gray-600">Gestion et suivi de tous les tickets d'incidents</p>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-red-50 p-3 rounded-lg">
              <AlertCircle className="w-6 h-6 text-red-600" />
            </div>
            <p className="text-red-600">{openIssues.length}</p>
          </div>
          <p className="text-gray-700">Nouveaux (Open)</p>
          <p className="text-gray-500 mt-1">Tickets en attente d'assignation</p>
        </div>

        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-orange-50 p-3 rounded-lg">
              <Clock className="w-6 h-6 text-orange-600" />
            </div>
            <p className="text-orange-600">{inProgressIssues.length}</p>
          </div>
          <p className="text-gray-700">En réparation (In Progress)</p>
          <p className="text-gray-500 mt-1">Interventions en cours</p>
        </div>

        <div className="bg-white p-6 rounded-lg border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <div className="bg-green-50 p-3 rounded-lg">
              <CheckCircle className="w-6 h-6 text-green-600" />
            </div>
            <p className="text-green-600">{resolvedIssues.length}</p>
          </div>
          <p className="text-gray-700">Résolus (Resolved)</p>
          <p className="text-gray-500 mt-1">Tickets clôturés</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        <div className="flex border-b border-gray-200">
          <button
            onClick={() => setActiveTab('Open')}
            className={`flex-1 px-6 py-4 transition-colors ${
              activeTab === 'Open'
                ? 'bg-red-50 text-red-700 border-b-2 border-red-600'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <div className="flex items-center justify-center gap-2">
              <AlertCircle className="w-5 h-5" />
              <span>Open ({openIssues.length})</span>
            </div>
          </button>
          <button
            onClick={() => setActiveTab('In Progress')}
            className={`flex-1 px-6 py-4 transition-colors ${
              activeTab === 'In Progress'
                ? 'bg-orange-50 text-orange-700 border-b-2 border-orange-600'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <div className="flex items-center justify-center gap-2">
              <Clock className="w-5 h-5" />
              <span>In Progress ({inProgressIssues.length})</span>
            </div>
          </button>
          <button
            onClick={() => setActiveTab('Resolved')}
            className={`flex-1 px-6 py-4 transition-colors ${
              activeTab === 'Resolved'
                ? 'bg-green-50 text-green-700 border-b-2 border-green-600'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <div className="flex items-center justify-center gap-2">
              <CheckCircle className="w-5 h-5" />
              <span>Resolved ({resolvedIssues.length})</span>
            </div>
          </button>
        </div>

        {/* Issues List */}
        <div className="p-6">
          {currentIssues.length > 0 ? (
            <div className="space-y-4">
              {currentIssues.map(issue => (
                <div
                  key={issue.id}
                  className="p-4 border border-gray-200 rounded-lg hover:border-blue-300 transition-colors"
                >
                  <div className="flex items-start justify-between mb-3">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <span className="px-3 py-1 bg-gray-100 text-gray-700 rounded">
                          {issue.id}
                        </span>
                        <span className={`px-3 py-1 rounded ${
                          issue.status === 'Open' 
                            ? 'bg-red-50 text-red-700' 
                            : issue.status === 'In Progress'
                            ? 'bg-orange-50 text-orange-700'
                            : 'bg-green-50 text-green-700'
                        }`}>
                          {issue.status}
                        </span>
                      </div>
                      <h3 className="text-gray-900 mb-1">{issue.equipmentName}</h3>
                      <p className="text-gray-600 mb-2">{issue.description}</p>
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-3">
                        <div>
                          <p className="text-gray-500">Département</p>
                          <p className="text-gray-900">{issue.department}</p>
                        </div>
                        <div>
                          <p className="text-gray-500">Type</p>
                          <p className="text-gray-900">{issue.type}</p>
                        </div>
                        <div>
                          <p className="text-gray-500">Date de création</p>
                          <p className="text-gray-900">{issue.createdAt}</p>
                        </div>
                        <div>
                          <p className="text-gray-500">Technicien assigné</p>
                          <p className="text-gray-900">{issue.assignedTechnician || 'Non assigné'}</p>
                        </div>
                      </div>
                    </div>
                    <button
                      onClick={() => onNavigate('technician-update', undefined, issue.id)}
                      className="ml-4 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2 whitespace-nowrap"
                    >
                      <Eye className="w-4 h-4" />
                      Voir / Mettre à jour
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-12">
              <p className="text-gray-500">Aucun ticket dans cette catégorie</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
