/// Route paths for all 18 LacakSaji screens (PRD Section 6 & DESIGN.md Section 6).
abstract final class AppRoutes {
  // Module A: Auth & Onboarding
  static const String splash = '/'; // S01
  static const String login = '/login'; // S02
  static const String register = '/register'; // S03
  static const String registerKitchen = '/register/kitchen'; // S03a
  static const String registerSchool = '/register/school'; // S03b
  static const String pendingVerification = '/pending-verification'; // S04

  // Module B: SPPG Kitchen (Role 1)
  static const String kitchenHome = '/kitchen'; // D01
  static const String kitchenCreateBatch = '/kitchen/batch/new'; // D02
  static const String kitchenBatchDetail = '/kitchen/batch/:batchId'; // D03
  static const String kitchenSchools = '/kitchen/schools'; // D04
  static const String kitchenHistory = '/kitchen/history'; // D05
  static const String kitchenSettings = '/kitchen/settings'; // C01 (Kitchen tab)

  // Module C: School PIC (Role 2)
  static const String schoolHome = '/school'; // G01
  static const String schoolScanQr = '/school/scan'; // G02
  static const String schoolDangerGate = '/school/inspection/gate'; // G03
  static const String schoolVisualAudit = '/school/inspection/audit'; // G04
  static const String schoolSampleSave = '/school/sample-save'; // G05 Step 3
  static const String schoolSamples = '/school/samples'; // G05 Tab Archive
  static const String schoolReportAlert = '/school/report'; // G06
  static const String schoolPuskesmasDraft = '/school/report/puskesmas-draft'; // G07 Draft KLB
  static const String schoolPlateWaste = '/school/plate-waste'; // G07 Plate-Waste tab
  static const String schoolSettings = '/school/settings'; // C01 (School tab)

  // Module D: Shared Settings & Supervisor (P1)
  static const String settings = '/settings'; // C01
  static const String supervisor = '/supervisor'; // B01

  static String batchDetailPath(String batchId) => '/kitchen/batch/$batchId';
}
