import 'package:flutter/foundation.dart';

import '../../kitchen/domain/kitchen_models.dart';

enum HighRiskIngredientPreset {
  ayamIkan('Ayam / Ikan Segar', 'Daging ayam, ikan fillet, atau olahan unggas'),
  tahuTempe('Tahu / Tempe', 'Produk kedelai segar tanpa pengawet'),
  susuUht('Susu UHT / Olahan', 'Susu kotak UHT atau produk susu lainnya'),
  telur('Telur / Olahan Telur', 'Telur ayam negeri, puyuh, atau telur olahan'),
  lainnya('Bahan Lainnya', 'Bumbu basah, sayuran, atau bahan utama lain');

  const HighRiskIngredientPreset(this.defaultName, this.hint);

  final String defaultName;
  final String hint;
}

bool isHighRiskIngredientName(String name) {
  final lower = name.trim().toLowerCase();
  const keywords = [
    'ayam',
    'ikan',
    'daging',
    'lele',
    'tongkol',
    'tuna',
    'tahu',
    'tempe',
    'susu',
    'uht',
    'telur',
    'udang',
    'bakso',
    'santan',
  ];
  return keywords.any(lower.contains);
}

class IngredientLogDraft {
  const IngredientLogDraft({
    required this.ingredientName,
    required this.supplierName,
    required this.supplierBatchNo,
    required this.expiryDate,
    this.notes,
  });

  final String ingredientName;
  final String supplierName;
  final String supplierBatchNo;
  final DateTime expiryDate;
  final String? notes;

  String get formattedExpiryDate => formatDateDdMmmYyyy(expiryDate);
}

String formatDateDdMmmYyyy(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final local = date.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = months[(local.month - 1).clamp(0, 11)];
  return '$dd $mm ${local.year}';
}

String formatSqlDate(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final yyyy = d.year.toString().padLeft(4, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

class IngredientLogItem {
  const IngredientLogItem({
    required this.id,
    required this.batchId,
    required this.sppgId,
    required this.ingredientName,
    required this.supplierName,
    required this.supplierBatchNo,
    required this.expiryDate,
    required this.receivedAtUtc,
    required this.createdAtUtc,
    this.batchCode,
    this.menuName,
    this.notes,
    this.createdBy,
    this.isPendingSync = false,
  });

  final String id;
  final String batchId;
  final String? batchCode;
  final String? menuName;
  final String sppgId;
  final String ingredientName;
  final String supplierName;
  final String supplierBatchNo;
  final DateTime expiryDate;
  final DateTime receivedAtUtc;
  final String? notes;
  final String? createdBy;
  final DateTime createdAtUtc;
  final bool isPendingSync;

  bool get isHighRisk => isHighRiskIngredientName(ingredientName);

  bool isExpiredAt(DateTime nowLocal) {
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return exp.isBefore(today);
  }

  bool isExpiringSoonAt(DateTime nowLocal, {int withinDays = 3}) {
    if (isExpiredAt(nowLocal)) {
      return true;
    }
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return exp.difference(today).inDays <= withinDays;
  }

  String get formattedExpiryDate => formatDateDdMmmYyyy(expiryDate);

  Map<String, dynamic> toDbInsertMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'sppg_id': sppgId,
      'ingredient_name': ingredientName.trim(),
      'supplier_name': supplierName.trim(),
      'supplier_batch_no': supplierBatchNo.trim(),
      'expiry_date': formatSqlDate(expiryDate),
      'received_at': receivedAtUtc.toUtc().toIso8601String(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (createdBy != null && createdBy!.trim().isNotEmpty)
        'created_by': createdBy,
      'created_at': createdAtUtc.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalDraftMap() {
    return {
      ...toDbInsertMap(),
      if (batchCode != null && batchCode!.isNotEmpty) 'batch_code': batchCode,
      if (menuName != null && menuName!.isNotEmpty) 'menu_name': menuName,
    };
  }

  factory IngredientLogItem.fromMap(
    Map<String, dynamic> map, {
    bool isPendingSync = false,
  }) {
    final batchJoin = map['food_batches'];
    String? joinedCode = map['batch_code'] as String?;
    String? joinedMenu = map['menu_name'] as String?;
    if (batchJoin is Map) {
      joinedCode ??= batchJoin['batch_code'] as String?;
      joinedMenu ??= batchJoin['menu_name'] as String?;
    }

    final parsedExp =
        DateTime.tryParse('${map['expiry_date'] ?? ''}') ?? DateTime.now();
    final parsedReceived =
        DateTime.tryParse('${map['received_at'] ?? ''}')?.toUtc() ??
        DateTime.now().toUtc();
    final parsedCreated =
        DateTime.tryParse('${map['created_at'] ?? ''}')?.toUtc() ??
        parsedReceived;

    return IngredientLogItem(
      id: (map['id'] as String?) ?? '',
      batchId: (map['batch_id'] as String?) ?? '',
      batchCode: joinedCode,
      menuName: joinedMenu,
      sppgId: (map['sppg_id'] as String?) ?? '',
      ingredientName: (map['ingredient_name'] as String?) ?? '-',
      supplierName: (map['supplier_name'] as String?) ?? '-',
      supplierBatchNo: (map['supplier_batch_no'] as String?) ?? '-',
      expiryDate: DateTime(parsedExp.year, parsedExp.month, parsedExp.day),
      receivedAtUtc: parsedReceived,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdAtUtc: parsedCreated,
      isPendingSync: isPendingSync,
    );
  }
}

enum CourierScanMode {
  loadAtKitchen('Scan Muat (Dapur)', 'Mengunci waktu berangkat dari SPPG'),
  arriveAtSchool('Scan Tiba (Sekolah)', 'Mengunci waktu tiba di gerbang sekolah');

  const CourierScanMode(this.label, this.subtitle);

  final String label;
  final String subtitle;
}

enum CourierDeliveryFilter {
  readyToLoad('Siap Muat'),
  inTransit('Dalam Perjalanan'),
  completed('Selesai');

  const CourierDeliveryFilter(this.label);

  final String label;
}

enum TransitHandoverDbStatus {
  loaded('loaded', 'Dimuat ke Mobil'),
  inTransit('in_transit', 'Dalam Perjalanan'),
  arrived('arrived', 'Tiba di Sekolah'),
  handedOver('handed_over', 'Diserahterimakan');

  const TransitHandoverDbStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static TransitHandoverDbStatus fromDb(String? value) {
    for (final status in TransitHandoverDbStatus.values) {
      if (status.dbValue == value) {
        return status;
      }
    }
    return TransitHandoverDbStatus.loaded;
  }
}

class TransitHandoverItem {
  const TransitHandoverItem({
    required this.id,
    required this.batchId,
    required this.sppgId,
    required this.courierName,
    required this.loadedAtUtc,
    required this.status,
    required this.createdAtUtc,
    this.batchCode,
    this.menuName,
    this.schoolId,
    this.schoolName,
    this.courierUserId,
    this.departedAtUtc,
    this.arrivedAtUtc,
    this.handedOverAtUtc,
    this.receivedByUserId,
    this.handoverNotes,
    this.loadLat,
    this.loadLng,
    this.arriveLat,
    this.arriveLng,
    this.isPendingSync = false,
  });

  final String id;
  final String batchId;
  final String? batchCode;
  final String? menuName;
  final String sppgId;
  final String? schoolId;
  final String? schoolName;
  final String? courierUserId;
  final String courierName;
  final DateTime loadedAtUtc;
  final DateTime? departedAtUtc;
  final DateTime? arrivedAtUtc;
  final DateTime? handedOverAtUtc;
  final String? receivedByUserId;
  final TransitHandoverDbStatus status;
  final String? handoverNotes;
  final double? loadLat;
  final double? loadLng;
  final double? arriveLat;
  final double? arriveLng;
  final DateTime createdAtUtc;
  final bool isPendingSync;

  DateTime get effectiveDepartedAtUtc => departedAtUtc ?? loadedAtUtc;

  int? get transitDurationMinutes {
    final end = arrivedAtUtc ?? handedOverAtUtc;
    if (end == null) {
      return null;
    }
    return end.toUtc().difference(effectiveDepartedAtUtc.toUtc()).inMinutes.clamp(
      0,
      1440,
    );
  }

  String? get loadCoordsText => (loadLat != null && loadLng != null)
      ? '${loadLat!.toStringAsFixed(5)}, ${loadLng!.toStringAsFixed(5)}'
      : null;

  String? get arriveCoordsText => (arriveLat != null && arriveLng != null)
      ? '${arriveLat!.toStringAsFixed(5)}, ${arriveLng!.toStringAsFixed(5)}'
      : null;

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'sppg_id': sppgId,
      if (schoolId != null && schoolId!.isNotEmpty) 'school_id': schoolId,
      if (courierUserId != null && courierUserId!.isNotEmpty)
        'courier_user_id': courierUserId,
      'courier_name': courierName.trim(),
      'loaded_at': loadedAtUtc.toUtc().toIso8601String(),
      if (departedAtUtc != null)
        'departed_at': departedAtUtc!.toUtc().toIso8601String(),
      if (arrivedAtUtc != null)
        'arrived_at': arrivedAtUtc!.toUtc().toIso8601String(),
      if (handedOverAtUtc != null)
        'handed_over_at': handedOverAtUtc!.toUtc().toIso8601String(),
      if (receivedByUserId != null && receivedByUserId!.isNotEmpty)
        'received_by_user_id': receivedByUserId,
      'status': status.dbValue,
      if (handoverNotes != null && handoverNotes!.trim().isNotEmpty)
        'handover_notes': handoverNotes!.trim(),
      if (loadLat != null) 'load_lat': loadLat,
      if (loadLng != null) 'load_lng': loadLng,
      if (arriveLat != null) 'arrive_lat': arriveLat,
      if (arriveLng != null) 'arrive_lng': arriveLng,
      'created_at': createdAtUtc.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalDraftMap() {
    return {
      ...toDbMap(),
      if (batchCode != null && batchCode!.isNotEmpty) 'batch_code': batchCode,
      if (menuName != null && menuName!.isNotEmpty) 'menu_name': menuName,
      if (schoolName != null && schoolName!.isNotEmpty)
        'school_name': schoolName,
    };
  }

  factory TransitHandoverItem.fromMap(
    Map<String, dynamic> map, {
    bool isPendingSync = false,
  }) {
    final schoolJoin = map['schools'];
    final batchJoin = map['food_batches'];

    var schoolName = map['school_name'] as String?;
    if (schoolJoin is Map) {
      schoolName ??= schoolJoin['name'] as String?;
    }

    var batchCode = map['batch_code'] as String?;
    var menuName = map['menu_name'] as String?;
    if (batchJoin is Map) {
      batchCode ??= batchJoin['batch_code'] as String?;
      menuName ??= batchJoin['menu_name'] as String?;
    }

    final loadedAt =
        DateTime.tryParse('${map['loaded_at'] ?? ''}')?.toUtc() ??
        DateTime.now().toUtc();
    final createdAt =
        DateTime.tryParse('${map['created_at'] ?? ''}')?.toUtc() ?? loadedAt;

    return TransitHandoverItem(
      id: (map['id'] as String?) ?? '',
      batchId: (map['batch_id'] as String?) ?? '',
      batchCode: batchCode,
      menuName: menuName,
      sppgId: (map['sppg_id'] as String?) ?? '',
      schoolId: map['school_id'] as String?,
      schoolName: schoolName,
      courierUserId: map['courier_user_id'] as String?,
      courierName: (map['courier_name'] as String?)?.trim().isNotEmpty == true
          ? (map['courier_name'] as String).trim()
          : 'Kurir SPPG',
      loadedAtUtc: loadedAt,
      departedAtUtc: DateTime.tryParse('${map['departed_at'] ?? ''}')?.toUtc(),
      arrivedAtUtc: DateTime.tryParse('${map['arrived_at'] ?? ''}')?.toUtc(),
      handedOverAtUtc: DateTime.tryParse(
        '${map['handed_over_at'] ?? ''}',
      )?.toUtc(),
      receivedByUserId: map['received_by_user_id'] as String?,
      status: TransitHandoverDbStatus.fromDb(map['status'] as String?),
      handoverNotes: map['handover_notes'] as String?,
      loadLat: (map['load_lat'] as num?)?.toDouble(),
      loadLng: (map['load_lng'] as num?)?.toDouble(),
      arriveLat: (map['arrive_lat'] as num?)?.toDouble(),
      arriveLng: (map['arrive_lng'] as num?)?.toDouble(),
      createdAtUtc: createdAt,
      isPendingSync: isPendingSync,
    );
  }
}

class CourierBatchDeliveryItem {
  const CourierBatchDeliveryItem({required this.batch, this.handover});

  final FoodBatchItem batch;
  final TransitHandoverItem? handover;

  CourierDeliveryFilter get stage {
    final h = handover;
    if (h == null) {
      return CourierDeliveryFilter.readyToLoad;
    }
    if (h.status == TransitHandoverDbStatus.arrived ||
        h.status == TransitHandoverDbStatus.handedOver ||
        h.arrivedAtUtc != null) {
      return CourierDeliveryFilter.completed;
    }
    return CourierDeliveryFilter.inTransit;
  }
}

class SupplyChainTimelineData {
  const SupplyChainTimelineData({
    required this.batchId,
    required this.sealedAtUtc,
    this.handover,
    this.schoolScannedAtUtc,
  });

  final String batchId;
  final DateTime sealedAtUtc;
  final TransitHandoverItem? handover;
  final DateTime? schoolScannedAtUtc;

  DateTime? get loadedAtUtc => handover?.effectiveDepartedAtUtc;

  DateTime? get arrivedAtUtc => handover?.arrivedAtUtc;

  int? get kitchenWaitMinutes {
    final loaded = loadedAtUtc;
    if (loaded == null) {
      return null;
    }
    return loaded.toUtc().difference(sealedAtUtc.toUtc()).inMinutes.clamp(
      0,
      1440,
    );
  }

  int? get courierTransitMinutes {
    final loaded = loadedAtUtc;
    final arrived = arrivedAtUtc ?? schoolScannedAtUtc;
    if (loaded == null || arrived == null) {
      return null;
    }
    return arrived.toUtc().difference(loaded.toUtc()).inMinutes.clamp(0, 1440);
  }

  int? get schoolGateWaitMinutes {
    final arrived = arrivedAtUtc;
    final scanned = schoolScannedAtUtc;
    if (arrived == null || scanned == null) {
      return null;
    }
    return scanned.toUtc().difference(arrived.toUtc()).inMinutes.clamp(0, 1440);
  }

  int? get totalElapsedMinutes {
    final end = schoolScannedAtUtc ?? arrivedAtUtc;
    if (end == null) {
      return null;
    }
    return end.toUtc().difference(sealedAtUtc.toUtc()).inMinutes.clamp(0, 1440);
  }

  bool get hasKitchenDelay =>
      kitchenWaitMinutes != null && kitchenWaitMinutes! >= 45;

  bool get hasRoadDelay =>
      courierTransitMinutes != null && courierTransitMinutes! >= 60;
}

@immutable
class TraySanitationChecklist {
  const TraySanitationChecklist({
    this.foodGradeSoapWash = false,
    this.hotRunningRinse = false,
    this.coveredDrying = false,
  });

  final bool foodGradeSoapWash;
  final bool hotRunningRinse;
  final bool coveredDrying;

  int get completedCount =>
      (foodGradeSoapWash ? 1 : 0) +
      (hotRunningRinse ? 1 : 0) +
      (coveredDrying ? 1 : 0);

  bool get isAllCompleted =>
      foodGradeSoapWash && hotRunningRinse && coveredDrying;

  TraySanitationChecklist copyWith({
    bool? foodGradeSoapWash,
    bool? hotRunningRinse,
    bool? coveredDrying,
  }) {
    return TraySanitationChecklist(
      foodGradeSoapWash: foodGradeSoapWash ?? this.foodGradeSoapWash,
      hotRunningRinse: hotRunningRinse ?? this.hotRunningRinse,
      coveredDrying: coveredDrying ?? this.coveredDrying,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'food_grade_soap_wash': foodGradeSoapWash,
      'hot_running_rinse': hotRunningRinse,
      'covered_drying': coveredDrying,
    };
  }

  factory TraySanitationChecklist.fromMap(Object? raw) {
    if (raw is! Map) {
      return const TraySanitationChecklist();
    }
    return TraySanitationChecklist(
      foodGradeSoapWash: raw['food_grade_soap_wash'] == true,
      hotRunningRinse: raw['hot_running_rinse'] == true,
      coveredDrying: raw['covered_drying'] == true,
    );
  }
}

enum TrayReturnStatus {
  pendingReturn('pending_return', 'Menunggu Kembali'),
  inReturnTransit('in_return_transit', 'Dikembalikan Sekolah'),
  receivedSppg('received_sppg', 'Diterima Dapur SPPG'),
  sanitized('sanitized', 'Tersanitasi');

  const TrayReturnStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static TrayReturnStatus fromDb(String? value) {
    for (final status in TrayReturnStatus.values) {
      if (status.dbValue == value) {
        return status;
      }
    }
    return TrayReturnStatus.pendingReturn;
  }
}

enum TraySanitizationStatus {
  pending('pending', 'Belum Dicuci'),
  washed('washed', 'Sedang Dicuci'),
  sanitizedVerified('sanitized_verified', 'Sanitasi Terverifikasi');

  const TraySanitizationStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static TraySanitizationStatus fromDb(String? value) {
    for (final status in TraySanitizationStatus.values) {
      if (status.dbValue == value) {
        return status;
      }
    }
    return TraySanitizationStatus.pending;
  }
}

class TrayReturnLogItem {
  const TrayReturnLogItem({
    required this.id,
    required this.batchId,
    required this.sppgId,
    required this.schoolId,
    required this.traysSent,
    required this.traysReturned,
    required this.missingTrays,
    required this.returnStatus,
    required this.sanitizationStatus,
    required this.createdAtUtc,
    this.batchCode,
    this.menuName,
    this.schoolName,
    this.checklist = const TraySanitationChecklist(),
    this.returnedAtUtc,
    this.sanitizedAtUtc,
    this.sanitizedBy,
    this.notes,
    this.isPendingSync = false,
  });

  final String id;
  final String batchId;
  final String? batchCode;
  final String? menuName;
  final String sppgId;
  final String schoolId;
  final String? schoolName;
  final int traysSent;
  final int traysReturned;
  final int missingTrays;
  final TrayReturnStatus returnStatus;
  final TraySanitizationStatus sanitizationStatus;
  final TraySanitationChecklist checklist;
  final DateTime? returnedAtUtc;
  final DateTime? sanitizedAtUtc;
  final String? sanitizedBy;
  final String? notes;
  final DateTime createdAtUtc;
  final bool isPendingSync;

  bool get hasDiscrepancy => missingTrays > 0;

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'sppg_id': sppgId,
      'school_id': schoolId,
      'trays_sent': traysSent,
      'trays_returned': traysReturned,
      'return_status': returnStatus.dbValue,
      'sanitization_status': sanitizationStatus.dbValue,
      'sanitization_checklist': checklist.toMap(),
      if (returnedAtUtc != null)
        'returned_at': returnedAtUtc!.toUtc().toIso8601String(),
      if (sanitizedAtUtc != null)
        'sanitized_at': sanitizedAtUtc!.toUtc().toIso8601String(),
      if (sanitizedBy != null && sanitizedBy!.isNotEmpty)
        'sanitized_by': sanitizedBy,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      'created_at': createdAtUtc.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalDraftMap() {
    return {
      ...toDbMap(),
      'missing_trays': missingTrays,
      if (batchCode != null && batchCode!.isNotEmpty) 'batch_code': batchCode,
      if (menuName != null && menuName!.isNotEmpty) 'menu_name': menuName,
      if (schoolName != null && schoolName!.isNotEmpty)
        'school_name': schoolName,
    };
  }

  factory TrayReturnLogItem.fromMap(
    Map<String, dynamic> map, {
    bool isPendingSync = false,
  }) {
    final schoolJoin = map['schools'];
    final batchJoin = map['food_batches'];

    var schoolName = map['school_name'] as String?;
    if (schoolJoin is Map) {
      schoolName ??= schoolJoin['name'] as String?;
    }

    var batchCode = map['batch_code'] as String?;
    var menuName = map['menu_name'] as String?;
    if (batchJoin is Map) {
      batchCode ??= batchJoin['batch_code'] as String?;
      menuName ??= batchJoin['menu_name'] as String?;
    }

    final sent = (map['trays_sent'] as num?)?.toInt() ?? 0;
    final returned = (map['trays_returned'] as num?)?.toInt() ?? 0;
    final computedMissing = (sent - returned) > 0 ? (sent - returned) : 0;
    final missing = (map['missing_trays'] as num?)?.toInt() ?? computedMissing;
    final createdAt =
        DateTime.tryParse('${map['created_at'] ?? ''}')?.toUtc() ??
        DateTime.now().toUtc();

    final parsedChecklist = TraySanitationChecklist.fromMap(
      map['sanitization_checklist'],
    );

    return TrayReturnLogItem(
      id: (map['id'] as String?) ?? '',
      batchId: (map['batch_id'] as String?) ?? '',
      batchCode: batchCode,
      menuName: menuName,
      sppgId: (map['sppg_id'] as String?) ?? '',
      schoolId: (map['school_id'] as String?) ?? '',
      schoolName: schoolName,
      traysSent: sent,
      traysReturned: returned,
      missingTrays: missing,
      returnStatus: TrayReturnStatus.fromDb(map['return_status'] as String?),
      sanitizationStatus: TraySanitizationStatus.fromDb(
        map['sanitization_status'] as String?,
      ),
      checklist: parsedChecklist,
      returnedAtUtc: DateTime.tryParse('${map['returned_at'] ?? ''}')?.toUtc(),
      sanitizedAtUtc: DateTime.tryParse(
        '${map['sanitized_at'] ?? ''}',
      )?.toUtc(),
      sanitizedBy: map['sanitized_by'] as String?,
      notes: map['notes'] as String?,
      createdAtUtc: createdAt,
      isPendingSync: isPendingSync,
    );
  }
}
