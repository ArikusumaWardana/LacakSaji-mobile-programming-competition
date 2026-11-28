/// Seeded demo accounts and sandbox codes documented in PRD_lacaksaji.md Section 2.2.
class DemoAccountPreset {
  const DemoAccountPreset({
    required this.email,
    required this.password,
    required this.title,
    required this.subtitle,
    required this.roleTag,
    required this.isKitchen,
    this.isSupervisor = false,
    this.isCourier = false,
  });

  final String email;
  final String password;
  final String title;
  final String subtitle;
  final String roleTag;
  final bool isKitchen;
  final bool isSupervisor;
  final bool isCourier;
}

class SandboxSppgCode {
  const SandboxSppgCode({
    required this.regNumber,
    required this.pin,
    required this.officialName,
    required this.regionName,
    required this.defaultAdm4,
  });

  final String regNumber;
  final String pin;
  final String officialName;
  final String regionName;
  final String defaultAdm4;
}

class Adm4VillageOption {
  const Adm4VillageOption({
    required this.code,
    required this.villageName,
    required this.districtName,
    required this.lat,
    required this.lng,
  });

  final String code;
  final String villageName;
  final String districtName;
  final double lat;
  final double lng;

  String get displayLabel => '$villageName, $districtName ($code)';
}

const String kDemoAccountPassword = String.fromEnvironment(
  'DEMO_PASSWORD',
  defaultValue: 'LacakSaji2026!',
);

const List<DemoAccountPreset> kDemoAccounts = [
  DemoAccountPreset(
    email: 'dapur.a@lacaksaji.id',
    password: kDemoAccountPassword,
    title: 'Dapur SPPG A (SPPG-PWT-01)',
    subtitle: 'SPPG Purwokerto Utara (Penyuplai SDN 1 & SDN 2 Purwokerto)',
    roleTag: 'DAPUR SPPG',
    isKitchen: true,
  ),
  DemoAccountPreset(
    email: 'sdn1.pwt@lacaksaji.id',
    password: kDemoAccountPassword,
    title: 'Sekolah 1: SDN 1 Purwokerto',
    subtitle: 'Mitra SPPG Purwokerto Utara (Status: Disetujui)',
    roleTag: 'SEKOLAH',
    isKitchen: false,
  ),
  DemoAccountPreset(
    email: 'sdn2.pwt@lacaksaji.id',
    password: kDemoAccountPassword,
    title: 'Sekolah 2: SDN 2 Purwokerto',
    subtitle: 'Mitra SPPG Purwokerto Utara (Status: Disetujui)',
    roleTag: 'SEKOLAH',
    isKitchen: false,
  ),
  DemoAccountPreset(
    email: 'sdn4.pwt@lacaksaji.id',
    password: kDemoAccountPassword,
    title: 'Sekolah 4: SDN 4 Purwokerto',
    subtitle: 'Mitra SPPG Purwokerto Utara (Status: Menunggu Persetujuan)',
    roleTag: 'SEKOLAH',
    isKitchen: false,
  ),
  DemoAccountPreset(
    email: 'dapur.b@lacaksaji.id',
    password: kDemoAccountPassword,
    title: 'Dapur SPPG B (SPPG-PWT-02)',
    subtitle: 'SPPG Sokaraja (Penyuplai SDN 1 Sokaraja)',
    roleTag: 'DAPUR SPPG',
    isKitchen: true,
  ),
  DemoAccountPreset(
    email: 'sdn1.sokaraja@lacaksaji.id',
    password: kDemoAccountPassword,
    title: 'Sekolah 3: SDN 1 Sokaraja',
    subtitle: 'Mitra SPPG Sokaraja (Status: Disetujui)',
    roleTag: 'SEKOLAH',
    isKitchen: false,
  ),
  DemoAccountPreset(
    email: 'pengawas.bgn@lacaksaji.id',
    password: kDemoAccountPassword,
    title: 'Mode Pengawas BGN (Hanya Baca)',
    subtitle: 'Pemantauan Kepatuhan Wilayah Banyumas',
    roleTag: 'PENGAWAS',
    isKitchen: false,
    isSupervisor: true,
  ),
  DemoAccountPreset(
    email: 'kurir.a@lacaksaji.id',
    password: kDemoAccountPassword,
    title: 'Kurir Pengantar: SPPG A',
    subtitle: 'Pengantaran SPPG Purwokerto Utara ke Sekolah Mitra',
    roleTag: 'KURIR',
    isKitchen: false,
    isCourier: true,
  ),
];

const List<SandboxSppgCode> kSandboxSppgCodes = [
  SandboxSppgCode(
    regNumber: 'BGN-SBX-2026-101',
    pin: '101010',
    officialName: 'SPPG Banyumas Barat (Sandbox 1)',
    regionName: 'Banyumas, Jawa Tengah',
    defaultAdm4: '33.02.11.2001',
  ),
  SandboxSppgCode(
    regNumber: 'BGN-SBX-2026-102',
    pin: '202020',
    officialName: 'SPPG Kembaran (Sandbox 2)',
    regionName: 'Banyumas, Jawa Tengah',
    defaultAdm4: '33.02.19.2001',
  ),
  SandboxSppgCode(
    regNumber: 'BGN-SBX-2026-103',
    pin: '303030',
    officialName: 'SPPG Ajibarang (Sandbox 3)',
    regionName: 'Banyumas, Jawa Tengah',
    defaultAdm4: '33.02.14.2001',
  ),
];

const List<Adm4VillageOption> kBanyumasAdm4Options = [
  Adm4VillageOption(
    code: '33.02.26.1001',
    villageName: 'Sumampir',
    districtName: 'Purwokerto Utara',
    lat: -7.4126,
    lng: 109.2345,
  ),
  Adm4VillageOption(
    code: '33.02.26.1003',
    villageName: 'Grendeng',
    districtName: 'Purwokerto Utara',
    lat: -7.4098,
    lng: 109.2471,
  ),
  Adm4VillageOption(
    code: '33.02.25.1001',
    villageName: 'Purwokerto Wetan',
    districtName: 'Purwokerto Timur',
    lat: -7.4285,
    lng: 109.2442,
  ),
  Adm4VillageOption(
    code: '33.02.24.1001',
    villageName: 'Kranji',
    districtName: 'Purwokerto Timur',
    lat: -7.4248,
    lng: 109.2371,
  ),
  Adm4VillageOption(
    code: '33.02.18.2005',
    villageName: 'Sokaraja Tengah',
    districtName: 'Sokaraja',
    lat: -7.4561,
    lng: 109.2869,
  ),
  Adm4VillageOption(
    code: '33.02.19.2001',
    villageName: 'Kembaran',
    districtName: 'Kembaran',
    lat: -7.4167,
    lng: 109.2792,
  ),
  Adm4VillageOption(
    code: '33.02.14.2001',
    villageName: 'Ajibarang Kulon',
    districtName: 'Ajibarang',
    lat: -7.4119,
    lng: 109.0715,
  ),
  Adm4VillageOption(
    code: '33.02.11.2001',
    villageName: 'Sudagaran',
    districtName: 'Banyumas',
    lat: -7.5159,
    lng: 109.2932,
  ),
];
