import 'package:supabase_flutter/supabase_flutter.dart';

import '../../alerts/domain/cluster_alert_models.dart';
import '../../kitchen/domain/kitchen_models.dart';
import '../domain/supervisor_models.dart';

abstract class SupervisorRepository {
  Future<SupervisorNationalOverview> fetchNationalOverview({
    required SupervisorDateFilter dateFilter,
    String regionFilter = 'Semua Wilayah',
  });
}

class SupabaseSupervisorRepository implements SupervisorRepository {
  SupabaseSupervisorRepository({
    required this._client,
    DateTime Function()? clockUtc,
  }) : _clockUtc = clockUtc ?? (() => DateTime.now().toUtc());

  final SupabaseClient? _client;
  final DateTime Function() _clockUtc;

  DateTime? _windowStartUtc(SupervisorDateFilter filter, DateTime nowUtc) {
    final days = filter.days;
    if (days == null) {
      return null;
    }
    if (days == 1) {
      final nowWib = toWibDateTime(nowUtc);
      final startOfWibDay = DateTime.utc(nowWib.year, nowWib.month, nowWib.day);
      return startOfWibDay.subtract(const Duration(hours: 7));
    }
    return nowUtc.subtract(Duration(days: days));
  }

  @override
  Future<SupervisorNationalOverview> fetchNationalOverview({
    required SupervisorDateFilter dateFilter,
    String regionFilter = 'Semua Wilayah',
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Konfigurasi server belum tersedia untuk Mode Pengawas.',
      );
    }

    final nowUtc = _clockUtc();
    final startUtc = _windowStartUtc(dateFilter, nowUtc);
    final startIso = startUtc?.toIso8601String();

    var batchesQuery = client
        .from('food_batches')
        .select('id, sppg_id, batch_code, menu_name, sealed_at');
    var inspectionsQuery = client
        .from('school_inspections')
        .select('id, batch_id, danger_status, final_decision, scanned_at');
    var alertsQuery = client
        .from('cluster_alerts')
        .select('id, sppg_id, batch_id, stage, symptom_count, created_at');
    var wasteQuery = client
        .from('plate_waste_logs')
        .select(
          'id, sppg_id, carb_waste_pct, protein_waste_pct, veg_waste_pct, created_at',
        );

    if (startIso != null) {
      batchesQuery = batchesQuery.gte('sealed_at', startIso);
      inspectionsQuery = inspectionsQuery.gte('scanned_at', startIso);
      alertsQuery = alertsQuery.gte('created_at', startIso);
      wasteQuery = wasteQuery.gte('created_at', startIso);
    }

    final results = await Future.wait<dynamic>([
      client
          .from('sppg_kitchens')
          .select('id, name, invite_code, adm4_code')
          .order('name', ascending: true),
      client.from('schools').select('id, sppg_id, verification_status'),
      batchesQuery.order('sealed_at', ascending: false),
      inspectionsQuery,
      alertsQuery.order('created_at', ascending: false),
      wasteQuery,
    ]);

    final kitchenRows = List<Map<String, dynamic>>.from(results[0] as List);
    final schoolRows = List<Map<String, dynamic>>.from(results[1] as List);
    final batchRows = List<Map<String, dynamic>>.from(results[2] as List);
    final inspectionRows = List<Map<String, dynamic>>.from(results[3] as List);
    final alertRows = List<Map<String, dynamic>>.from(results[4] as List);
    final wasteRows = List<Map<String, dynamic>>.from(results[5] as List);

    final kitchenById = <String, Map<String, dynamic>>{};
    final regionByKitchenId = <String, String>{};
    final regionSet = <String>{};

    for (final k in kitchenRows) {
      final id = k['id'] as String;
      final adm4 = (k['adm4_code'] as String?) ?? '';
      final region = resolveSupervisorRegionName(adm4);
      kitchenById[id] = k;
      regionByKitchenId[id] = region;
      regionSet.add(region);
    }

    final sortedRegions = regionSet.toList()..sort();
    final availableRegions = <String>['Semua Wilayah', ...sortedRegions];
    final effectiveRegion = availableRegions.contains(regionFilter)
        ? regionFilter
        : 'Semua Wilayah';

    final includedKitchenIds = kitchenRows
        .where(
          (k) =>
              effectiveRegion == 'Semua Wilayah' ||
              regionByKitchenId[k['id'] as String] == effectiveRegion,
        )
        .map((k) => k['id'] as String)
        .toSet();

    final batchById = <String, Map<String, dynamic>>{};
    for (final b in batchRows) {
      batchById[b['id'] as String] = b;
    }

    final problemBatchIds = <String>{};
    for (final insp in inspectionRows) {
      final danger = insp['danger_status'] as String?;
      final decision = insp['final_decision'] as String?;
      if (danger == 'RED' || decision == 'REJECTED') {
        final batchId = insp['batch_id'] as String?;
        if (batchId != null) {
          problemBatchIds.add(batchId);
        }
      }
    }

    final activeAlerts = <SupervisorAlertBrief>[];
    final alertsByKitchen = <String, int>{};

    for (final alert in alertRows) {
      final sppgId = (alert['sppg_id'] as String?) ?? '';
      final batchId = (alert['batch_id'] as String?) ?? '';
      if (batchId.isNotEmpty) {
        problemBatchIds.add(batchId);
      }
      if (!includedKitchenIds.contains(sppgId)) {
        continue;
      }
      alertsByKitchen[sppgId] = (alertsByKitchen[sppgId] ?? 0) + 1;
      final kitchen = kitchenById[sppgId];
      final batch = batchById[batchId];
      activeAlerts.add(
        SupervisorAlertBrief(
          id: alert['id'] as String,
          sppgId: sppgId,
          sppgName: sanitizeZeroSlopCopy(
            (kitchen?['name'] as String?) ?? 'Dapur SPPG',
          ),
          menuName: sanitizeZeroSlopCopy(
            (batch?['menu_name'] as String?) ?? 'Menu Batch Terkait',
          ),
          batchCode: sanitizeZeroSlopCopy(
            (batch?['batch_code'] as String?) ?? '-',
          ),
          stage: ClusterAlertStage.fromDb(alert['stage'] as String?),
          symptomCount: (alert['symptom_count'] as num?)?.toInt() ?? 0,
          createdAtUtc:
              DateTime.tryParse((alert['created_at'] as String?) ?? '')
                  ?.toUtc() ??
              nowUtc,
        ),
      );
    }

    final approvedSchoolsByKitchen = <String, int>{};
    for (final s in schoolRows) {
      final sppgId = s['sppg_id'] as String?;
      final status = s['verification_status'] as String?;
      if (sppgId != null &&
          status == 'approved' &&
          includedKitchenIds.contains(sppgId)) {
        approvedSchoolsByKitchen[sppgId] =
            (approvedSchoolsByKitchen[sppgId] ?? 0) + 1;
      }
    }

    final totalBatchesByKitchen = <String, int>{};
    final problemBatchesByKitchen = <String, int>{};
    for (final b in batchRows) {
      final batchId = b['id'] as String;
      final sppgId = (b['sppg_id'] as String?) ?? '';
      if (!includedKitchenIds.contains(sppgId)) {
        continue;
      }
      totalBatchesByKitchen[sppgId] = (totalBatchesByKitchen[sppgId] ?? 0) + 1;
      if (problemBatchIds.contains(batchId)) {
        problemBatchesByKitchen[sppgId] =
            (problemBatchesByKitchen[sppgId] ?? 0) + 1;
      }
    }

    final wasteStatsByKitchen = <String, _WasteAccumulator>{};
    final nationalWaste = _WasteAccumulator();
    for (final w in wasteRows) {
      final sppgId = (w['sppg_id'] as String?) ?? '';
      if (!includedKitchenIds.contains(sppgId)) {
        continue;
      }
      final carb = (w['carb_waste_pct'] as num?)?.toInt() ?? 0;
      final protein = (w['protein_waste_pct'] as num?)?.toInt() ?? 0;
      final veg = (w['veg_waste_pct'] as num?)?.toInt() ?? 0;
      (wasteStatsByKitchen[sppgId] ??= _WasteAccumulator()).add(
        carb: carb,
        protein: protein,
        veg: veg,
      );
      nationalWaste.add(carb: carb, protein: protein, veg: veg);
    }

    final summaries = <SupervisorSppgSummary>[];
    var totalApprovedSchools = 0;
    var totalBatches = 0;
    var totalSafeBatches = 0;
    var totalProblemBatches = 0;

    for (final k in kitchenRows) {
      final sppgId = k['id'] as String;
      if (!includedKitchenIds.contains(sppgId)) {
        continue;
      }
      final schoolCount = approvedSchoolsByKitchen[sppgId] ?? 0;
      final batchCount = totalBatchesByKitchen[sppgId] ?? 0;
      final problemCount = problemBatchesByKitchen[sppgId] ?? 0;
      final safeCount = batchCount >= problemCount ? batchCount - problemCount : 0;
      final alertCount = alertsByKitchen[sppgId] ?? 0;
      final wasteAcc = wasteStatsByKitchen[sppgId] ?? _WasteAccumulator();

      totalApprovedSchools += schoolCount;
      totalBatches += batchCount;
      totalSafeBatches += safeCount;
      totalProblemBatches += problemCount;

      summaries.add(
        SupervisorSppgSummary(
          sppgId: sppgId,
          sppgName: sanitizeZeroSlopCopy((k['name'] as String?) ?? 'Dapur SPPG'),
          inviteCode: sanitizeZeroSlopCopy(
            (k['invite_code'] as String?) ?? '-',
          ),
          adm4Code: (k['adm4_code'] as String?) ?? '',
          regionName: regionByKitchenId[sppgId] ?? 'Wilayah Lainnya',
          approvedSchoolCount: schoolCount,
          totalBatches: batchCount,
          safeBatches: safeCount,
          problemBatches: problemCount,
          activeAlertsCount: alertCount,
          avgCarbWastePct: wasteAcc.avgCarb,
          avgProteinWastePct: wasteAcc.avgProtein,
          avgVegWastePct: wasteAcc.avgVeg,
          avgOverallWastePct: wasteAcc.avgOverall,
          wasteLogCount: wasteAcc.count,
        ),
      );
    }

    return SupervisorNationalOverview(
      dateFilter: dateFilter,
      regionFilter: effectiveRegion,
      availableRegions: availableRegions,
      totalSppgCount: summaries.length,
      totalApprovedSchoolsCount: totalApprovedSchools,
      totalBatches: totalBatches,
      safeBatches: totalSafeBatches,
      problemBatches: totalProblemBatches,
      activeAlertsCount: activeAlerts.length,
      avgWastePct: nationalWaste.avgOverall,
      activeAlerts: activeAlerts,
      sppgSummaries: summaries,
      generatedAtUtc: nowUtc,
    );
  }
}

class _WasteAccumulator {
  int count = 0;
  int carbSum = 0;
  int proteinSum = 0;
  int vegSum = 0;

  void add({required int carb, required int protein, required int veg}) {
    count++;
    carbSum += carb;
    proteinSum += protein;
    vegSum += veg;
  }

  int get avgCarb => count == 0 ? 0 : (carbSum / count).round();
  int get avgProtein => count == 0 ? 0 : (proteinSum / count).round();
  int get avgVeg => count == 0 ? 0 : (vegSum / count).round();
  int get avgOverall =>
      count == 0 ? 0 : ((carbSum + proteinSum + vegSum) / (count * 3)).round();
}
