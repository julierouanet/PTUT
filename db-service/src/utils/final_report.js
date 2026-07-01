// ── Rapport final équipement (résumé interventions + KPI) ───────────────────
// Logique de calcul PURE (sans accès DB) des KPI et de l'historique du rapport
// final équipement. Source de vérité unique, testable indépendamment d'Express
// (même approche que utils/replacement.js pour le plan de remplacement).

const round1 = (n) => Math.round(n * 10) / 10;

// Construit { equipment_id, equipment_name, summary, interventions } à partir
// des lignes d'interventions résolues d'un équipement (chaque ligne : issue_id,
// resolved_at, technician_name, hours_open, duration_hours, root_cause, summary,
// report_status, max_loop — cf. GET /api/equipment/:id/final-report).
function buildEquipmentFinalReport(equipment, rows) {
  const total = rows.length;

  const mttrHoursAvg = total > 0
    ? round1(rows.reduce((sum, r) => sum + r.hours_open, 0) / total)
    : null;
  const reopenedCount = rows.filter((r) => (r.max_loop || 0) > 1).length;
  const reopenedRatePct = total > 0 ? round1((reopenedCount / total) * 100) : null;
  const downtimeHoursTotal = round1(
    rows.filter((r) => r.report_status === 'finalized')
        .reduce((sum, r) => sum + (r.duration_hours || 0), 0)
  );

  return {
    equipment_id: equipment.id,
    equipment_name: equipment.name,
    summary: {
      total_interventions: total,
      mttr_hours_avg: mttrHoursAvg,
      reopened_rate_pct: reopenedRatePct,
      downtime_hours_total: downtimeHoursTotal,
    },
    interventions: rows.map((r) => ({
      issue_id: r.issue_id,
      resolved_at: r.resolved_at,
      technician_name: r.technician_name || null,
      duration_hours: r.duration_hours != null ? r.duration_hours : null,
      root_cause: r.root_cause || null,
      summary: r.summary || null,
      reopened: (r.max_loop || 0) > 1,
    })),
  };
}

module.exports = { buildEquipmentFinalReport };
