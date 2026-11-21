import '../../../core/constants/demo_accounts.dart';
import '../../alerts/domain/cluster_alert_models.dart';

/// Date range selector for B01 read-only supervisor monitoring.
enum SupervisorDateFilter {
  today('Hari Ini', 1),
  last7Days('7 Hari', 7),
  last30Days('30 Hari', 30),
  all('Semua', null);

  const SupervisorDateFilter(this.label, this.days);

  final String label;
  final int? days;
}

/// Read-only active Cluster Alert summary item shown on B01.
class SupervisorAlertBrief {
  const SupervisorAlertBrief({
    required this.id,
    required this.sppgId,
    required this.sppgName,
    required this.menuName,
    required this.batchCode,
    required this.stage,
    required this.symptomCount,
    required this.createdAtUtc,
  });

  final String id;
  final String sppgId;
  final String sppgName;
  final String menuName;
  final String batchCode;
  final ClusterAlertStage stage;
  final int symptomCount;
  final DateTime createdAtUtc;
}

/// Aggregated compliance and plate-waste record for a single SPPG kitchen on B01.
class SupervisorSppgSummary {
  const SupervisorSppgSummary({
    required this.sppgId,
    required this.sppgName,
    required this.inviteCode,
    required this.adm4Code,
    required this.regionName,
    required this.approvedSchoolCount,
    required this.totalBatches,
    required this.safeBatches,
    required this.problemBatches,
    required this.activeAlertsCount,
    required this.avgCarbWastePct,
    required this.avgProteinWastePct,
    required this.avgVegWastePct,
    required this.avgOverallWastePct,
    required this.wasteLogCount,
  });

  final String sppgId;
  final String sppgName;
  final String inviteCode;
  final String adm4Code;
  final String regionName;
  final int approvedSchoolCount;
  final int totalBatches;
  final int safeBatches;
  final int problemBatches;
  final int activeAlertsCount;
  final int avgCarbWastePct;
  final int avgProteinWastePct;
  final int avgVegWastePct;
  final int avgOverallWastePct;
  final int wasteLogCount;

  bool get needsAttention =>
      activeAlertsCount > 0 ||
      problemBatches > 0 ||
      (wasteLogCount > 0 && avgOverallWastePct >= 40);
}

/// National / regional read-only overview aggregated across SPPG kitchens for B01.
class SupervisorNationalOverview {
  const SupervisorNationalOverview({
    required this.dateFilter,
    required this.regionFilter,
    required this.availableRegions,
    required this.totalSppgCount,
    required this.totalApprovedSchoolsCount,
    required this.totalBatches,
    required this.safeBatches,
    required this.problemBatches,
    required this.activeAlertsCount,
    required this.avgWastePct,
    required this.activeAlerts,
    required this.sppgSummaries,
    required this.generatedAtUtc,
  });

  final SupervisorDateFilter dateFilter;
  final String regionFilter;
  final List<String> availableRegions;
  final int totalSppgCount;
  final int totalApprovedSchoolsCount;
  final int totalBatches;
  final int safeBatches;
  final int problemBatches;
  final int activeAlertsCount;
  final int avgWastePct;
  final List<SupervisorAlertBrief> activeAlerts;
  final List<SupervisorSppgSummary> sppgSummaries;
  final DateTime generatedAtUtc;
}

/// Resolves human-readable kecamatan/wilayah name from BMKG adm4 village code.
String resolveSupervisorRegionName(String adm4Code) {
  final clean = adm4Code.trim();
  for (final option in kBanyumasAdm4Options) {
    if (option.code == clean) {
      return option.districtName;
    }
  }
  if (clean.startsWith('33.02.26')) return 'Purwokerto Utara';
  if (clean.startsWith('33.02.25') || clean.startsWith('33.02.24')) {
    return 'Purwokerto Timur';
  }
  if (clean.startsWith('33.02.18')) return 'Sokaraja';
  if (clean.startsWith('33.02.19')) return 'Kembaran';
  if (clean.startsWith('33.02.14')) return 'Ajibarang';
  if (clean.startsWith('33.02.11')) return 'Banyumas';
  return clean.isEmpty ? 'Wilayah Lainnya' : clean;
}
