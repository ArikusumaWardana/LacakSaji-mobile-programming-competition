// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalSppgKeysTable extends LocalSppgKeys
    with TableInfo<$LocalSppgKeysTable, LocalSppgKey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSppgKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sppgIdMeta = const VerificationMeta('sppgId');
  @override
  late final GeneratedColumn<String> sppgId = GeneratedColumn<String>(
    'sppg_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sppgNameMeta = const VerificationMeta(
    'sppgName',
  );
  @override
  late final GeneratedColumn<String> sppgName = GeneratedColumn<String>(
    'sppg_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inviteCodeMeta = const VerificationMeta(
    'inviteCode',
  );
  @override
  late final GeneratedColumn<String> inviteCode = GeneratedColumn<String>(
    'invite_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publicKeyB64Meta = const VerificationMeta(
    'publicKeyB64',
  );
  @override
  late final GeneratedColumn<String> publicKeyB64 = GeneratedColumn<String>(
    'public_key_b64',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sppgId,
    sppgName,
    inviteCode,
    publicKeyB64,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sppg_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSppgKey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sppg_id')) {
      context.handle(
        _sppgIdMeta,
        sppgId.isAcceptableOrUnknown(data['sppg_id']!, _sppgIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sppgIdMeta);
    }
    if (data.containsKey('sppg_name')) {
      context.handle(
        _sppgNameMeta,
        sppgName.isAcceptableOrUnknown(data['sppg_name']!, _sppgNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sppgNameMeta);
    }
    if (data.containsKey('invite_code')) {
      context.handle(
        _inviteCodeMeta,
        inviteCode.isAcceptableOrUnknown(data['invite_code']!, _inviteCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_inviteCodeMeta);
    }
    if (data.containsKey('public_key_b64')) {
      context.handle(
        _publicKeyB64Meta,
        publicKeyB64.isAcceptableOrUnknown(
          data['public_key_b64']!,
          _publicKeyB64Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publicKeyB64Meta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sppgId};
  @override
  LocalSppgKey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSppgKey(
      sppgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sppg_id'],
      )!,
      sppgName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sppg_name'],
      )!,
      inviteCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invite_code'],
      )!,
      publicKeyB64: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_key_b64'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalSppgKeysTable createAlias(String alias) {
    return $LocalSppgKeysTable(attachedDatabase, alias);
  }
}

class LocalSppgKey extends DataClass implements Insertable<LocalSppgKey> {
  final String sppgId;
  final String sppgName;
  final String inviteCode;
  final String publicKeyB64;
  final DateTime updatedAt;
  const LocalSppgKey({
    required this.sppgId,
    required this.sppgName,
    required this.inviteCode,
    required this.publicKeyB64,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sppg_id'] = Variable<String>(sppgId);
    map['sppg_name'] = Variable<String>(sppgName);
    map['invite_code'] = Variable<String>(inviteCode);
    map['public_key_b64'] = Variable<String>(publicKeyB64);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalSppgKeysCompanion toCompanion(bool nullToAbsent) {
    return LocalSppgKeysCompanion(
      sppgId: Value(sppgId),
      sppgName: Value(sppgName),
      inviteCode: Value(inviteCode),
      publicKeyB64: Value(publicKeyB64),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalSppgKey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSppgKey(
      sppgId: serializer.fromJson<String>(json['sppgId']),
      sppgName: serializer.fromJson<String>(json['sppgName']),
      inviteCode: serializer.fromJson<String>(json['inviteCode']),
      publicKeyB64: serializer.fromJson<String>(json['publicKeyB64']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sppgId': serializer.toJson<String>(sppgId),
      'sppgName': serializer.toJson<String>(sppgName),
      'inviteCode': serializer.toJson<String>(inviteCode),
      'publicKeyB64': serializer.toJson<String>(publicKeyB64),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalSppgKey copyWith({
    String? sppgId,
    String? sppgName,
    String? inviteCode,
    String? publicKeyB64,
    DateTime? updatedAt,
  }) => LocalSppgKey(
    sppgId: sppgId ?? this.sppgId,
    sppgName: sppgName ?? this.sppgName,
    inviteCode: inviteCode ?? this.inviteCode,
    publicKeyB64: publicKeyB64 ?? this.publicKeyB64,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalSppgKey copyWithCompanion(LocalSppgKeysCompanion data) {
    return LocalSppgKey(
      sppgId: data.sppgId.present ? data.sppgId.value : this.sppgId,
      sppgName: data.sppgName.present ? data.sppgName.value : this.sppgName,
      inviteCode: data.inviteCode.present
          ? data.inviteCode.value
          : this.inviteCode,
      publicKeyB64: data.publicKeyB64.present
          ? data.publicKeyB64.value
          : this.publicKeyB64,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSppgKey(')
          ..write('sppgId: $sppgId, ')
          ..write('sppgName: $sppgName, ')
          ..write('inviteCode: $inviteCode, ')
          ..write('publicKeyB64: $publicKeyB64, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sppgId, sppgName, inviteCode, publicKeyB64, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSppgKey &&
          other.sppgId == this.sppgId &&
          other.sppgName == this.sppgName &&
          other.inviteCode == this.inviteCode &&
          other.publicKeyB64 == this.publicKeyB64 &&
          other.updatedAt == this.updatedAt);
}

class LocalSppgKeysCompanion extends UpdateCompanion<LocalSppgKey> {
  final Value<String> sppgId;
  final Value<String> sppgName;
  final Value<String> inviteCode;
  final Value<String> publicKeyB64;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalSppgKeysCompanion({
    this.sppgId = const Value.absent(),
    this.sppgName = const Value.absent(),
    this.inviteCode = const Value.absent(),
    this.publicKeyB64 = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSppgKeysCompanion.insert({
    required String sppgId,
    required String sppgName,
    required String inviteCode,
    required String publicKeyB64,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : sppgId = Value(sppgId),
       sppgName = Value(sppgName),
       inviteCode = Value(inviteCode),
       publicKeyB64 = Value(publicKeyB64),
       updatedAt = Value(updatedAt);
  static Insertable<LocalSppgKey> custom({
    Expression<String>? sppgId,
    Expression<String>? sppgName,
    Expression<String>? inviteCode,
    Expression<String>? publicKeyB64,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sppgId != null) 'sppg_id': sppgId,
      if (sppgName != null) 'sppg_name': sppgName,
      if (inviteCode != null) 'invite_code': inviteCode,
      if (publicKeyB64 != null) 'public_key_b64': publicKeyB64,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSppgKeysCompanion copyWith({
    Value<String>? sppgId,
    Value<String>? sppgName,
    Value<String>? inviteCode,
    Value<String>? publicKeyB64,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalSppgKeysCompanion(
      sppgId: sppgId ?? this.sppgId,
      sppgName: sppgName ?? this.sppgName,
      inviteCode: inviteCode ?? this.inviteCode,
      publicKeyB64: publicKeyB64 ?? this.publicKeyB64,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sppgId.present) {
      map['sppg_id'] = Variable<String>(sppgId.value);
    }
    if (sppgName.present) {
      map['sppg_name'] = Variable<String>(sppgName.value);
    }
    if (inviteCode.present) {
      map['invite_code'] = Variable<String>(inviteCode.value);
    }
    if (publicKeyB64.present) {
      map['public_key_b64'] = Variable<String>(publicKeyB64.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSppgKeysCompanion(')
          ..write('sppgId: $sppgId, ')
          ..write('sppgName: $sppgName, ')
          ..write('inviteCode: $inviteCode, ')
          ..write('publicKeyB64: $publicKeyB64, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalBmkgCacheTable extends LocalBmkgCache
    with TableInfo<$LocalBmkgCacheTable, LocalBmkgCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBmkgCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _adm4CodeMeta = const VerificationMeta(
    'adm4Code',
  );
  @override
  late final GeneratedColumn<String> adm4Code = GeneratedColumn<String>(
    'adm4_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _forecastTimeUtcMeta = const VerificationMeta(
    'forecastTimeUtc',
  );
  @override
  late final GeneratedColumn<DateTime> forecastTimeUtc =
      GeneratedColumn<DateTime>(
        'forecast_time_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _temperatureCMeta = const VerificationMeta(
    'temperatureC',
  );
  @override
  late final GeneratedColumn<double> temperatureC = GeneratedColumn<double>(
    'temperature_c',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _humidityPctMeta = const VerificationMeta(
    'humidityPct',
  );
  @override
  late final GeneratedColumn<int> humidityPct = GeneratedColumn<int>(
    'humidity_pct',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weatherDescMeta = const VerificationMeta(
    'weatherDesc',
  );
  @override
  late final GeneratedColumn<String> weatherDesc = GeneratedColumn<String>(
    'weather_desc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    adm4Code,
    forecastTimeUtc,
    temperatureC,
    humidityPct,
    weatherDesc,
    fetchedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_bmkg_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBmkgCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('adm4_code')) {
      context.handle(
        _adm4CodeMeta,
        adm4Code.isAcceptableOrUnknown(data['adm4_code']!, _adm4CodeMeta),
      );
    } else if (isInserting) {
      context.missing(_adm4CodeMeta);
    }
    if (data.containsKey('forecast_time_utc')) {
      context.handle(
        _forecastTimeUtcMeta,
        forecastTimeUtc.isAcceptableOrUnknown(
          data['forecast_time_utc']!,
          _forecastTimeUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_forecastTimeUtcMeta);
    }
    if (data.containsKey('temperature_c')) {
      context.handle(
        _temperatureCMeta,
        temperatureC.isAcceptableOrUnknown(
          data['temperature_c']!,
          _temperatureCMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_temperatureCMeta);
    }
    if (data.containsKey('humidity_pct')) {
      context.handle(
        _humidityPctMeta,
        humidityPct.isAcceptableOrUnknown(
          data['humidity_pct']!,
          _humidityPctMeta,
        ),
      );
    }
    if (data.containsKey('weather_desc')) {
      context.handle(
        _weatherDescMeta,
        weatherDesc.isAcceptableOrUnknown(
          data['weather_desc']!,
          _weatherDescMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBmkgCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBmkgCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      adm4Code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}adm4_code'],
      )!,
      forecastTimeUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}forecast_time_utc'],
      )!,
      temperatureC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature_c'],
      )!,
      humidityPct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}humidity_pct'],
      ),
      weatherDesc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weather_desc'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $LocalBmkgCacheTable createAlias(String alias) {
    return $LocalBmkgCacheTable(attachedDatabase, alias);
  }
}

class LocalBmkgCacheData extends DataClass
    implements Insertable<LocalBmkgCacheData> {
  final int id;
  final String adm4Code;
  final DateTime forecastTimeUtc;
  final double temperatureC;
  final int? humidityPct;
  final String? weatherDesc;
  final DateTime fetchedAt;
  final DateTime expiresAt;
  const LocalBmkgCacheData({
    required this.id,
    required this.adm4Code,
    required this.forecastTimeUtc,
    required this.temperatureC,
    this.humidityPct,
    this.weatherDesc,
    required this.fetchedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['adm4_code'] = Variable<String>(adm4Code);
    map['forecast_time_utc'] = Variable<DateTime>(forecastTimeUtc);
    map['temperature_c'] = Variable<double>(temperatureC);
    if (!nullToAbsent || humidityPct != null) {
      map['humidity_pct'] = Variable<int>(humidityPct);
    }
    if (!nullToAbsent || weatherDesc != null) {
      map['weather_desc'] = Variable<String>(weatherDesc);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  LocalBmkgCacheCompanion toCompanion(bool nullToAbsent) {
    return LocalBmkgCacheCompanion(
      id: Value(id),
      adm4Code: Value(adm4Code),
      forecastTimeUtc: Value(forecastTimeUtc),
      temperatureC: Value(temperatureC),
      humidityPct: humidityPct == null && nullToAbsent
          ? const Value.absent()
          : Value(humidityPct),
      weatherDesc: weatherDesc == null && nullToAbsent
          ? const Value.absent()
          : Value(weatherDesc),
      fetchedAt: Value(fetchedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory LocalBmkgCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBmkgCacheData(
      id: serializer.fromJson<int>(json['id']),
      adm4Code: serializer.fromJson<String>(json['adm4Code']),
      forecastTimeUtc: serializer.fromJson<DateTime>(json['forecastTimeUtc']),
      temperatureC: serializer.fromJson<double>(json['temperatureC']),
      humidityPct: serializer.fromJson<int?>(json['humidityPct']),
      weatherDesc: serializer.fromJson<String?>(json['weatherDesc']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'adm4Code': serializer.toJson<String>(adm4Code),
      'forecastTimeUtc': serializer.toJson<DateTime>(forecastTimeUtc),
      'temperatureC': serializer.toJson<double>(temperatureC),
      'humidityPct': serializer.toJson<int?>(humidityPct),
      'weatherDesc': serializer.toJson<String?>(weatherDesc),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  LocalBmkgCacheData copyWith({
    int? id,
    String? adm4Code,
    DateTime? forecastTimeUtc,
    double? temperatureC,
    Value<int?> humidityPct = const Value.absent(),
    Value<String?> weatherDesc = const Value.absent(),
    DateTime? fetchedAt,
    DateTime? expiresAt,
  }) => LocalBmkgCacheData(
    id: id ?? this.id,
    adm4Code: adm4Code ?? this.adm4Code,
    forecastTimeUtc: forecastTimeUtc ?? this.forecastTimeUtc,
    temperatureC: temperatureC ?? this.temperatureC,
    humidityPct: humidityPct.present ? humidityPct.value : this.humidityPct,
    weatherDesc: weatherDesc.present ? weatherDesc.value : this.weatherDesc,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  LocalBmkgCacheData copyWithCompanion(LocalBmkgCacheCompanion data) {
    return LocalBmkgCacheData(
      id: data.id.present ? data.id.value : this.id,
      adm4Code: data.adm4Code.present ? data.adm4Code.value : this.adm4Code,
      forecastTimeUtc: data.forecastTimeUtc.present
          ? data.forecastTimeUtc.value
          : this.forecastTimeUtc,
      temperatureC: data.temperatureC.present
          ? data.temperatureC.value
          : this.temperatureC,
      humidityPct: data.humidityPct.present
          ? data.humidityPct.value
          : this.humidityPct,
      weatherDesc: data.weatherDesc.present
          ? data.weatherDesc.value
          : this.weatherDesc,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBmkgCacheData(')
          ..write('id: $id, ')
          ..write('adm4Code: $adm4Code, ')
          ..write('forecastTimeUtc: $forecastTimeUtc, ')
          ..write('temperatureC: $temperatureC, ')
          ..write('humidityPct: $humidityPct, ')
          ..write('weatherDesc: $weatherDesc, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    adm4Code,
    forecastTimeUtc,
    temperatureC,
    humidityPct,
    weatherDesc,
    fetchedAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBmkgCacheData &&
          other.id == this.id &&
          other.adm4Code == this.adm4Code &&
          other.forecastTimeUtc == this.forecastTimeUtc &&
          other.temperatureC == this.temperatureC &&
          other.humidityPct == this.humidityPct &&
          other.weatherDesc == this.weatherDesc &&
          other.fetchedAt == this.fetchedAt &&
          other.expiresAt == this.expiresAt);
}

class LocalBmkgCacheCompanion extends UpdateCompanion<LocalBmkgCacheData> {
  final Value<int> id;
  final Value<String> adm4Code;
  final Value<DateTime> forecastTimeUtc;
  final Value<double> temperatureC;
  final Value<int?> humidityPct;
  final Value<String?> weatherDesc;
  final Value<DateTime> fetchedAt;
  final Value<DateTime> expiresAt;
  const LocalBmkgCacheCompanion({
    this.id = const Value.absent(),
    this.adm4Code = const Value.absent(),
    this.forecastTimeUtc = const Value.absent(),
    this.temperatureC = const Value.absent(),
    this.humidityPct = const Value.absent(),
    this.weatherDesc = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  LocalBmkgCacheCompanion.insert({
    this.id = const Value.absent(),
    required String adm4Code,
    required DateTime forecastTimeUtc,
    required double temperatureC,
    this.humidityPct = const Value.absent(),
    this.weatherDesc = const Value.absent(),
    required DateTime fetchedAt,
    required DateTime expiresAt,
  }) : adm4Code = Value(adm4Code),
       forecastTimeUtc = Value(forecastTimeUtc),
       temperatureC = Value(temperatureC),
       fetchedAt = Value(fetchedAt),
       expiresAt = Value(expiresAt);
  static Insertable<LocalBmkgCacheData> custom({
    Expression<int>? id,
    Expression<String>? adm4Code,
    Expression<DateTime>? forecastTimeUtc,
    Expression<double>? temperatureC,
    Expression<int>? humidityPct,
    Expression<String>? weatherDesc,
    Expression<DateTime>? fetchedAt,
    Expression<DateTime>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (adm4Code != null) 'adm4_code': adm4Code,
      if (forecastTimeUtc != null) 'forecast_time_utc': forecastTimeUtc,
      if (temperatureC != null) 'temperature_c': temperatureC,
      if (humidityPct != null) 'humidity_pct': humidityPct,
      if (weatherDesc != null) 'weather_desc': weatherDesc,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  LocalBmkgCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? adm4Code,
    Value<DateTime>? forecastTimeUtc,
    Value<double>? temperatureC,
    Value<int?>? humidityPct,
    Value<String?>? weatherDesc,
    Value<DateTime>? fetchedAt,
    Value<DateTime>? expiresAt,
  }) {
    return LocalBmkgCacheCompanion(
      id: id ?? this.id,
      adm4Code: adm4Code ?? this.adm4Code,
      forecastTimeUtc: forecastTimeUtc ?? this.forecastTimeUtc,
      temperatureC: temperatureC ?? this.temperatureC,
      humidityPct: humidityPct ?? this.humidityPct,
      weatherDesc: weatherDesc ?? this.weatherDesc,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (adm4Code.present) {
      map['adm4_code'] = Variable<String>(adm4Code.value);
    }
    if (forecastTimeUtc.present) {
      map['forecast_time_utc'] = Variable<DateTime>(forecastTimeUtc.value);
    }
    if (temperatureC.present) {
      map['temperature_c'] = Variable<double>(temperatureC.value);
    }
    if (humidityPct.present) {
      map['humidity_pct'] = Variable<int>(humidityPct.value);
    }
    if (weatherDesc.present) {
      map['weather_desc'] = Variable<String>(weatherDesc.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBmkgCacheCompanion(')
          ..write('id: $id, ')
          ..write('adm4Code: $adm4Code, ')
          ..write('forecastTimeUtc: $forecastTimeUtc, ')
          ..write('temperatureC: $temperatureC, ')
          ..write('humidityPct: $humidityPct, ')
          ..write('weatherDesc: $weatherDesc, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $LocalSyncQueueTable extends LocalSyncQueue
    with TableInfo<$LocalSyncQueueTable, LocalSyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPhotoPathsJsonMeta =
      const VerificationMeta('localPhotoPathsJson');
  @override
  late final GeneratedColumn<String> localPhotoPathsJson =
      GeneratedColumn<String>(
        'local_photo_paths_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationType,
    entityId,
    payloadJson,
    localPhotoPathsJson,
    status,
    retryCount,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('local_photo_paths_json')) {
      context.handle(
        _localPhotoPathsJsonMeta,
        localPhotoPathsJson.isAcceptableOrUnknown(
          data['local_photo_paths_json']!,
          _localPhotoPathsJsonMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      localPhotoPathsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_photo_paths_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalSyncQueueTable createAlias(String alias) {
    return $LocalSyncQueueTable(attachedDatabase, alias);
  }
}

class LocalSyncQueueData extends DataClass
    implements Insertable<LocalSyncQueueData> {
  final int id;

  /// One of: create_batch, create_inspection, create_sample, create_waste_log, create_alert.
  final String operationType;
  final String entityId;
  final String payloadJson;
  final String localPhotoPathsJson;

  /// One of: pending, syncing, failed.
  final String status;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalSyncQueueData({
    required this.id,
    required this.operationType,
    required this.entityId,
    required this.payloadJson,
    required this.localPhotoPathsJson,
    required this.status,
    required this.retryCount,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation_type'] = Variable<String>(operationType);
    map['entity_id'] = Variable<String>(entityId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['local_photo_paths_json'] = Variable<String>(localPhotoPathsJson);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalSyncQueueCompanion toCompanion(bool nullToAbsent) {
    return LocalSyncQueueCompanion(
      id: Value(id),
      operationType: Value(operationType),
      entityId: Value(entityId),
      payloadJson: Value(payloadJson),
      localPhotoPathsJson: Value(localPhotoPathsJson),
      status: Value(status),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalSyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      operationType: serializer.fromJson<String>(json['operationType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      localPhotoPathsJson: serializer.fromJson<String>(
        json['localPhotoPathsJson'],
      ),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operationType': serializer.toJson<String>(operationType),
      'entityId': serializer.toJson<String>(entityId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'localPhotoPathsJson': serializer.toJson<String>(localPhotoPathsJson),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalSyncQueueData copyWith({
    int? id,
    String? operationType,
    String? entityId,
    String? payloadJson,
    String? localPhotoPathsJson,
    String? status,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalSyncQueueData(
    id: id ?? this.id,
    operationType: operationType ?? this.operationType,
    entityId: entityId ?? this.entityId,
    payloadJson: payloadJson ?? this.payloadJson,
    localPhotoPathsJson: localPhotoPathsJson ?? this.localPhotoPathsJson,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalSyncQueueData copyWithCompanion(LocalSyncQueueCompanion data) {
    return LocalSyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      localPhotoPathsJson: data.localPhotoPathsJson.present
          ? data.localPhotoPathsJson.value
          : this.localPhotoPathsJson,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSyncQueueData(')
          ..write('id: $id, ')
          ..write('operationType: $operationType, ')
          ..write('entityId: $entityId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('localPhotoPathsJson: $localPhotoPathsJson, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operationType,
    entityId,
    payloadJson,
    localPhotoPathsJson,
    status,
    retryCount,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSyncQueueData &&
          other.id == this.id &&
          other.operationType == this.operationType &&
          other.entityId == this.entityId &&
          other.payloadJson == this.payloadJson &&
          other.localPhotoPathsJson == this.localPhotoPathsJson &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalSyncQueueCompanion extends UpdateCompanion<LocalSyncQueueData> {
  final Value<int> id;
  final Value<String> operationType;
  final Value<String> entityId;
  final Value<String> payloadJson;
  final Value<String> localPhotoPathsJson;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const LocalSyncQueueCompanion({
    this.id = const Value.absent(),
    this.operationType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.localPhotoPathsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LocalSyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String operationType,
    required String entityId,
    required String payloadJson,
    this.localPhotoPathsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : operationType = Value(operationType),
       entityId = Value(entityId),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalSyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? operationType,
    Expression<String>? entityId,
    Expression<String>? payloadJson,
    Expression<String>? localPhotoPathsJson,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationType != null) 'operation_type': operationType,
      if (entityId != null) 'entity_id': entityId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (localPhotoPathsJson != null)
        'local_photo_paths_json': localPhotoPathsJson,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LocalSyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? operationType,
    Value<String>? entityId,
    Value<String>? payloadJson,
    Value<String>? localPhotoPathsJson,
    Value<String>? status,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return LocalSyncQueueCompanion(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      entityId: entityId ?? this.entityId,
      payloadJson: payloadJson ?? this.payloadJson,
      localPhotoPathsJson: localPhotoPathsJson ?? this.localPhotoPathsJson,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (localPhotoPathsJson.present) {
      map['local_photo_paths_json'] = Variable<String>(
        localPhotoPathsJson.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('operationType: $operationType, ')
          ..write('entityId: $entityId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('localPhotoPathsJson: $localPhotoPathsJson, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalSampleVaultsTable extends LocalSampleVaults
    with TableInfo<$LocalSampleVaultsTable, LocalSampleVault> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSampleVaultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inspectionIdMeta = const VerificationMeta(
    'inspectionId',
  );
  @override
  late final GeneratedColumn<String> inspectionId = GeneratedColumn<String>(
    'inspection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schoolIdMeta = const VerificationMeta(
    'schoolId',
  );
  @override
  late final GeneratedColumn<String> schoolId = GeneratedColumn<String>(
    'school_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _menuNameMeta = const VerificationMeta(
    'menuName',
  );
  @override
  late final GeneratedColumn<String> menuName = GeneratedColumn<String>(
    'menu_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelCodeMeta = const VerificationMeta(
    'labelCode',
  );
  @override
  late final GeneratedColumn<String> labelCode = GeneratedColumn<String>(
    'label_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _storedAtMeta = const VerificationMeta(
    'storedAt',
  );
  @override
  late final GeneratedColumn<DateTime> storedAt = GeneratedColumn<DateTime>(
    'stored_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    inspectionId,
    schoolId,
    menuName,
    labelCode,
    storedAt,
    expiresAt,
    status,
    isSynced,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sample_vaults';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSampleVault> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('inspection_id')) {
      context.handle(
        _inspectionIdMeta,
        inspectionId.isAcceptableOrUnknown(
          data['inspection_id']!,
          _inspectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inspectionIdMeta);
    }
    if (data.containsKey('school_id')) {
      context.handle(
        _schoolIdMeta,
        schoolId.isAcceptableOrUnknown(data['school_id']!, _schoolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_schoolIdMeta);
    }
    if (data.containsKey('menu_name')) {
      context.handle(
        _menuNameMeta,
        menuName.isAcceptableOrUnknown(data['menu_name']!, _menuNameMeta),
      );
    } else if (isInserting) {
      context.missing(_menuNameMeta);
    }
    if (data.containsKey('label_code')) {
      context.handle(
        _labelCodeMeta,
        labelCode.isAcceptableOrUnknown(data['label_code']!, _labelCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_labelCodeMeta);
    }
    if (data.containsKey('stored_at')) {
      context.handle(
        _storedAtMeta,
        storedAt.isAcceptableOrUnknown(data['stored_at']!, _storedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_storedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSampleVault map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSampleVault(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      inspectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inspection_id'],
      )!,
      schoolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_id'],
      )!,
      menuName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}menu_name'],
      )!,
      labelCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_code'],
      )!,
      storedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}stored_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalSampleVaultsTable createAlias(String alias) {
    return $LocalSampleVaultsTable(attachedDatabase, alias);
  }
}

class LocalSampleVault extends DataClass
    implements Insertable<LocalSampleVault> {
  final String id;
  final String inspectionId;
  final String schoolId;
  final String menuName;
  final String labelCode;
  final DateTime storedAt;
  final DateTime expiresAt;

  /// One of: active, disposed, lab_submitted.
  final String status;
  final bool isSynced;
  final DateTime createdAt;
  const LocalSampleVault({
    required this.id,
    required this.inspectionId,
    required this.schoolId,
    required this.menuName,
    required this.labelCode,
    required this.storedAt,
    required this.expiresAt,
    required this.status,
    required this.isSynced,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['inspection_id'] = Variable<String>(inspectionId);
    map['school_id'] = Variable<String>(schoolId);
    map['menu_name'] = Variable<String>(menuName);
    map['label_code'] = Variable<String>(labelCode);
    map['stored_at'] = Variable<DateTime>(storedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['status'] = Variable<String>(status);
    map['is_synced'] = Variable<bool>(isSynced);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalSampleVaultsCompanion toCompanion(bool nullToAbsent) {
    return LocalSampleVaultsCompanion(
      id: Value(id),
      inspectionId: Value(inspectionId),
      schoolId: Value(schoolId),
      menuName: Value(menuName),
      labelCode: Value(labelCode),
      storedAt: Value(storedAt),
      expiresAt: Value(expiresAt),
      status: Value(status),
      isSynced: Value(isSynced),
      createdAt: Value(createdAt),
    );
  }

  factory LocalSampleVault.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSampleVault(
      id: serializer.fromJson<String>(json['id']),
      inspectionId: serializer.fromJson<String>(json['inspectionId']),
      schoolId: serializer.fromJson<String>(json['schoolId']),
      menuName: serializer.fromJson<String>(json['menuName']),
      labelCode: serializer.fromJson<String>(json['labelCode']),
      storedAt: serializer.fromJson<DateTime>(json['storedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      status: serializer.fromJson<String>(json['status']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'inspectionId': serializer.toJson<String>(inspectionId),
      'schoolId': serializer.toJson<String>(schoolId),
      'menuName': serializer.toJson<String>(menuName),
      'labelCode': serializer.toJson<String>(labelCode),
      'storedAt': serializer.toJson<DateTime>(storedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'status': serializer.toJson<String>(status),
      'isSynced': serializer.toJson<bool>(isSynced),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalSampleVault copyWith({
    String? id,
    String? inspectionId,
    String? schoolId,
    String? menuName,
    String? labelCode,
    DateTime? storedAt,
    DateTime? expiresAt,
    String? status,
    bool? isSynced,
    DateTime? createdAt,
  }) => LocalSampleVault(
    id: id ?? this.id,
    inspectionId: inspectionId ?? this.inspectionId,
    schoolId: schoolId ?? this.schoolId,
    menuName: menuName ?? this.menuName,
    labelCode: labelCode ?? this.labelCode,
    storedAt: storedAt ?? this.storedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    status: status ?? this.status,
    isSynced: isSynced ?? this.isSynced,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalSampleVault copyWithCompanion(LocalSampleVaultsCompanion data) {
    return LocalSampleVault(
      id: data.id.present ? data.id.value : this.id,
      inspectionId: data.inspectionId.present
          ? data.inspectionId.value
          : this.inspectionId,
      schoolId: data.schoolId.present ? data.schoolId.value : this.schoolId,
      menuName: data.menuName.present ? data.menuName.value : this.menuName,
      labelCode: data.labelCode.present ? data.labelCode.value : this.labelCode,
      storedAt: data.storedAt.present ? data.storedAt.value : this.storedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      status: data.status.present ? data.status.value : this.status,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSampleVault(')
          ..write('id: $id, ')
          ..write('inspectionId: $inspectionId, ')
          ..write('schoolId: $schoolId, ')
          ..write('menuName: $menuName, ')
          ..write('labelCode: $labelCode, ')
          ..write('storedAt: $storedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('status: $status, ')
          ..write('isSynced: $isSynced, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    inspectionId,
    schoolId,
    menuName,
    labelCode,
    storedAt,
    expiresAt,
    status,
    isSynced,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSampleVault &&
          other.id == this.id &&
          other.inspectionId == this.inspectionId &&
          other.schoolId == this.schoolId &&
          other.menuName == this.menuName &&
          other.labelCode == this.labelCode &&
          other.storedAt == this.storedAt &&
          other.expiresAt == this.expiresAt &&
          other.status == this.status &&
          other.isSynced == this.isSynced &&
          other.createdAt == this.createdAt);
}

class LocalSampleVaultsCompanion extends UpdateCompanion<LocalSampleVault> {
  final Value<String> id;
  final Value<String> inspectionId;
  final Value<String> schoolId;
  final Value<String> menuName;
  final Value<String> labelCode;
  final Value<DateTime> storedAt;
  final Value<DateTime> expiresAt;
  final Value<String> status;
  final Value<bool> isSynced;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalSampleVaultsCompanion({
    this.id = const Value.absent(),
    this.inspectionId = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.menuName = const Value.absent(),
    this.labelCode = const Value.absent(),
    this.storedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSampleVaultsCompanion.insert({
    required String id,
    required String inspectionId,
    required String schoolId,
    required String menuName,
    required String labelCode,
    required DateTime storedAt,
    required DateTime expiresAt,
    this.status = const Value.absent(),
    this.isSynced = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       inspectionId = Value(inspectionId),
       schoolId = Value(schoolId),
       menuName = Value(menuName),
       labelCode = Value(labelCode),
       storedAt = Value(storedAt),
       expiresAt = Value(expiresAt),
       createdAt = Value(createdAt);
  static Insertable<LocalSampleVault> custom({
    Expression<String>? id,
    Expression<String>? inspectionId,
    Expression<String>? schoolId,
    Expression<String>? menuName,
    Expression<String>? labelCode,
    Expression<DateTime>? storedAt,
    Expression<DateTime>? expiresAt,
    Expression<String>? status,
    Expression<bool>? isSynced,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (inspectionId != null) 'inspection_id': inspectionId,
      if (schoolId != null) 'school_id': schoolId,
      if (menuName != null) 'menu_name': menuName,
      if (labelCode != null) 'label_code': labelCode,
      if (storedAt != null) 'stored_at': storedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (status != null) 'status': status,
      if (isSynced != null) 'is_synced': isSynced,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSampleVaultsCompanion copyWith({
    Value<String>? id,
    Value<String>? inspectionId,
    Value<String>? schoolId,
    Value<String>? menuName,
    Value<String>? labelCode,
    Value<DateTime>? storedAt,
    Value<DateTime>? expiresAt,
    Value<String>? status,
    Value<bool>? isSynced,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalSampleVaultsCompanion(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      schoolId: schoolId ?? this.schoolId,
      menuName: menuName ?? this.menuName,
      labelCode: labelCode ?? this.labelCode,
      storedAt: storedAt ?? this.storedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (inspectionId.present) {
      map['inspection_id'] = Variable<String>(inspectionId.value);
    }
    if (schoolId.present) {
      map['school_id'] = Variable<String>(schoolId.value);
    }
    if (menuName.present) {
      map['menu_name'] = Variable<String>(menuName.value);
    }
    if (labelCode.present) {
      map['label_code'] = Variable<String>(labelCode.value);
    }
    if (storedAt.present) {
      map['stored_at'] = Variable<DateTime>(storedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSampleVaultsCompanion(')
          ..write('id: $id, ')
          ..write('inspectionId: $inspectionId, ')
          ..write('schoolId: $schoolId, ')
          ..write('menuName: $menuName, ')
          ..write('labelCode: $labelCode, ')
          ..write('storedAt: $storedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('status: $status, ')
          ..write('isSynced: $isSynced, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalSppgKeysTable localSppgKeys = $LocalSppgKeysTable(this);
  late final $LocalBmkgCacheTable localBmkgCache = $LocalBmkgCacheTable(this);
  late final $LocalSyncQueueTable localSyncQueue = $LocalSyncQueueTable(this);
  late final $LocalSampleVaultsTable localSampleVaults =
      $LocalSampleVaultsTable(this);
  late final Index idxBmkgAdm4Forecast = Index(
    'idx_bmkg_adm4_forecast',
    'CREATE UNIQUE INDEX idx_bmkg_adm4_forecast ON local_bmkg_cache (adm4_code, forecast_time_utc)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localSppgKeys,
    localBmkgCache,
    localSyncQueue,
    localSampleVaults,
    idxBmkgAdm4Forecast,
  ];
}

typedef $$LocalSppgKeysTableCreateCompanionBuilder =
    LocalSppgKeysCompanion Function({
      required String sppgId,
      required String sppgName,
      required String inviteCode,
      required String publicKeyB64,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalSppgKeysTableUpdateCompanionBuilder =
    LocalSppgKeysCompanion Function({
      Value<String> sppgId,
      Value<String> sppgName,
      Value<String> inviteCode,
      Value<String> publicKeyB64,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalSppgKeysTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSppgKeysTable> {
  $$LocalSppgKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sppgId => $composableBuilder(
    column: $table.sppgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sppgName => $composableBuilder(
    column: $table.sppgName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inviteCode => $composableBuilder(
    column: $table.inviteCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicKeyB64 => $composableBuilder(
    column: $table.publicKeyB64,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSppgKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSppgKeysTable> {
  $$LocalSppgKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sppgId => $composableBuilder(
    column: $table.sppgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sppgName => $composableBuilder(
    column: $table.sppgName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inviteCode => $composableBuilder(
    column: $table.inviteCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicKeyB64 => $composableBuilder(
    column: $table.publicKeyB64,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSppgKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSppgKeysTable> {
  $$LocalSppgKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sppgId =>
      $composableBuilder(column: $table.sppgId, builder: (column) => column);

  GeneratedColumn<String> get sppgName =>
      $composableBuilder(column: $table.sppgName, builder: (column) => column);

  GeneratedColumn<String> get inviteCode => $composableBuilder(
    column: $table.inviteCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publicKeyB64 => $composableBuilder(
    column: $table.publicKeyB64,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalSppgKeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSppgKeysTable,
          LocalSppgKey,
          $$LocalSppgKeysTableFilterComposer,
          $$LocalSppgKeysTableOrderingComposer,
          $$LocalSppgKeysTableAnnotationComposer,
          $$LocalSppgKeysTableCreateCompanionBuilder,
          $$LocalSppgKeysTableUpdateCompanionBuilder,
          (
            LocalSppgKey,
            BaseReferences<_$AppDatabase, $LocalSppgKeysTable, LocalSppgKey>,
          ),
          LocalSppgKey,
          PrefetchHooks Function()
        > {
  $$LocalSppgKeysTableTableManager(_$AppDatabase db, $LocalSppgKeysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSppgKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSppgKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSppgKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sppgId = const Value.absent(),
                Value<String> sppgName = const Value.absent(),
                Value<String> inviteCode = const Value.absent(),
                Value<String> publicKeyB64 = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSppgKeysCompanion(
                sppgId: sppgId,
                sppgName: sppgName,
                inviteCode: inviteCode,
                publicKeyB64: publicKeyB64,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sppgId,
                required String sppgName,
                required String inviteCode,
                required String publicKeyB64,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalSppgKeysCompanion.insert(
                sppgId: sppgId,
                sppgName: sppgName,
                inviteCode: inviteCode,
                publicKeyB64: publicKeyB64,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSppgKeysTable, LocalSppgKey>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSppgKeysTable,
                    LocalSppgKey
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSppgKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSppgKeysTable,
      LocalSppgKey,
      $$LocalSppgKeysTableFilterComposer,
      $$LocalSppgKeysTableOrderingComposer,
      $$LocalSppgKeysTableAnnotationComposer,
      $$LocalSppgKeysTableCreateCompanionBuilder,
      $$LocalSppgKeysTableUpdateCompanionBuilder,
      (
        LocalSppgKey,
        BaseReferences<_$AppDatabase, $LocalSppgKeysTable, LocalSppgKey>,
      ),
      LocalSppgKey,
      PrefetchHooks Function()
    >;
typedef $$LocalBmkgCacheTableCreateCompanionBuilder =
    LocalBmkgCacheCompanion Function({
      Value<int> id,
      required String adm4Code,
      required DateTime forecastTimeUtc,
      required double temperatureC,
      Value<int?> humidityPct,
      Value<String?> weatherDesc,
      required DateTime fetchedAt,
      required DateTime expiresAt,
    });
typedef $$LocalBmkgCacheTableUpdateCompanionBuilder =
    LocalBmkgCacheCompanion Function({
      Value<int> id,
      Value<String> adm4Code,
      Value<DateTime> forecastTimeUtc,
      Value<double> temperatureC,
      Value<int?> humidityPct,
      Value<String?> weatherDesc,
      Value<DateTime> fetchedAt,
      Value<DateTime> expiresAt,
    });

class $$LocalBmkgCacheTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBmkgCacheTable> {
  $$LocalBmkgCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adm4Code => $composableBuilder(
    column: $table.adm4Code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get forecastTimeUtc => $composableBuilder(
    column: $table.forecastTimeUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get humidityPct => $composableBuilder(
    column: $table.humidityPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weatherDesc => $composableBuilder(
    column: $table.weatherDesc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBmkgCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBmkgCacheTable> {
  $$LocalBmkgCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adm4Code => $composableBuilder(
    column: $table.adm4Code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get forecastTimeUtc => $composableBuilder(
    column: $table.forecastTimeUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get humidityPct => $composableBuilder(
    column: $table.humidityPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weatherDesc => $composableBuilder(
    column: $table.weatherDesc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBmkgCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBmkgCacheTable> {
  $$LocalBmkgCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get adm4Code =>
      $composableBuilder(column: $table.adm4Code, builder: (column) => column);

  GeneratedColumn<DateTime> get forecastTimeUtc => $composableBuilder(
    column: $table.forecastTimeUtc,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => column,
  );

  GeneratedColumn<int> get humidityPct => $composableBuilder(
    column: $table.humidityPct,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weatherDesc => $composableBuilder(
    column: $table.weatherDesc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$LocalBmkgCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBmkgCacheTable,
          LocalBmkgCacheData,
          $$LocalBmkgCacheTableFilterComposer,
          $$LocalBmkgCacheTableOrderingComposer,
          $$LocalBmkgCacheTableAnnotationComposer,
          $$LocalBmkgCacheTableCreateCompanionBuilder,
          $$LocalBmkgCacheTableUpdateCompanionBuilder,
          (
            LocalBmkgCacheData,
            BaseReferences<
              _$AppDatabase,
              $LocalBmkgCacheTable,
              LocalBmkgCacheData
            >,
          ),
          LocalBmkgCacheData,
          PrefetchHooks Function()
        > {
  $$LocalBmkgCacheTableTableManager(
    _$AppDatabase db,
    $LocalBmkgCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBmkgCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBmkgCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBmkgCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> adm4Code = const Value.absent(),
                Value<DateTime> forecastTimeUtc = const Value.absent(),
                Value<double> temperatureC = const Value.absent(),
                Value<int?> humidityPct = const Value.absent(),
                Value<String?> weatherDesc = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
              }) => LocalBmkgCacheCompanion(
                id: id,
                adm4Code: adm4Code,
                forecastTimeUtc: forecastTimeUtc,
                temperatureC: temperatureC,
                humidityPct: humidityPct,
                weatherDesc: weatherDesc,
                fetchedAt: fetchedAt,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String adm4Code,
                required DateTime forecastTimeUtc,
                required double temperatureC,
                Value<int?> humidityPct = const Value.absent(),
                Value<String?> weatherDesc = const Value.absent(),
                required DateTime fetchedAt,
                required DateTime expiresAt,
              }) => LocalBmkgCacheCompanion.insert(
                id: id,
                adm4Code: adm4Code,
                forecastTimeUtc: forecastTimeUtc,
                temperatureC: temperatureC,
                humidityPct: humidityPct,
                weatherDesc: weatherDesc,
                fetchedAt: fetchedAt,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalBmkgCacheTable, LocalBmkgCacheData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalBmkgCacheTable,
                    LocalBmkgCacheData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBmkgCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBmkgCacheTable,
      LocalBmkgCacheData,
      $$LocalBmkgCacheTableFilterComposer,
      $$LocalBmkgCacheTableOrderingComposer,
      $$LocalBmkgCacheTableAnnotationComposer,
      $$LocalBmkgCacheTableCreateCompanionBuilder,
      $$LocalBmkgCacheTableUpdateCompanionBuilder,
      (
        LocalBmkgCacheData,
        BaseReferences<_$AppDatabase, $LocalBmkgCacheTable, LocalBmkgCacheData>,
      ),
      LocalBmkgCacheData,
      PrefetchHooks Function()
    >;
typedef $$LocalSyncQueueTableCreateCompanionBuilder =
    LocalSyncQueueCompanion Function({
      Value<int> id,
      required String operationType,
      required String entityId,
      required String payloadJson,
      Value<String> localPhotoPathsJson,
      Value<String> status,
      Value<int> retryCount,
      Value<String?> lastError,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$LocalSyncQueueTableUpdateCompanionBuilder =
    LocalSyncQueueCompanion Function({
      Value<int> id,
      Value<String> operationType,
      Value<String> entityId,
      Value<String> payloadJson,
      Value<String> localPhotoPathsJson,
      Value<String> status,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$LocalSyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSyncQueueTable> {
  $$LocalSyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPhotoPathsJson => $composableBuilder(
    column: $table.localPhotoPathsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSyncQueueTable> {
  $$LocalSyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPhotoPathsJson => $composableBuilder(
    column: $table.localPhotoPathsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSyncQueueTable> {
  $$LocalSyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPhotoPathsJson => $composableBuilder(
    column: $table.localPhotoPathsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalSyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSyncQueueTable,
          LocalSyncQueueData,
          $$LocalSyncQueueTableFilterComposer,
          $$LocalSyncQueueTableOrderingComposer,
          $$LocalSyncQueueTableAnnotationComposer,
          $$LocalSyncQueueTableCreateCompanionBuilder,
          $$LocalSyncQueueTableUpdateCompanionBuilder,
          (
            LocalSyncQueueData,
            BaseReferences<
              _$AppDatabase,
              $LocalSyncQueueTable,
              LocalSyncQueueData
            >,
          ),
          LocalSyncQueueData,
          PrefetchHooks Function()
        > {
  $$LocalSyncQueueTableTableManager(
    _$AppDatabase db,
    $LocalSyncQueueTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> localPhotoPathsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LocalSyncQueueCompanion(
                id: id,
                operationType: operationType,
                entityId: entityId,
                payloadJson: payloadJson,
                localPhotoPathsJson: localPhotoPathsJson,
                status: status,
                retryCount: retryCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operationType,
                required String entityId,
                required String payloadJson,
                Value<String> localPhotoPathsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => LocalSyncQueueCompanion.insert(
                id: id,
                operationType: operationType,
                entityId: entityId,
                payloadJson: payloadJson,
                localPhotoPathsJson: localPhotoPathsJson,
                status: status,
                retryCount: retryCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSyncQueueTable, LocalSyncQueueData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSyncQueueTable,
                    LocalSyncQueueData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSyncQueueTable,
      LocalSyncQueueData,
      $$LocalSyncQueueTableFilterComposer,
      $$LocalSyncQueueTableOrderingComposer,
      $$LocalSyncQueueTableAnnotationComposer,
      $$LocalSyncQueueTableCreateCompanionBuilder,
      $$LocalSyncQueueTableUpdateCompanionBuilder,
      (
        LocalSyncQueueData,
        BaseReferences<_$AppDatabase, $LocalSyncQueueTable, LocalSyncQueueData>,
      ),
      LocalSyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$LocalSampleVaultsTableCreateCompanionBuilder =
    LocalSampleVaultsCompanion Function({
      required String id,
      required String inspectionId,
      required String schoolId,
      required String menuName,
      required String labelCode,
      required DateTime storedAt,
      required DateTime expiresAt,
      Value<String> status,
      Value<bool> isSynced,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalSampleVaultsTableUpdateCompanionBuilder =
    LocalSampleVaultsCompanion Function({
      Value<String> id,
      Value<String> inspectionId,
      Value<String> schoolId,
      Value<String> menuName,
      Value<String> labelCode,
      Value<DateTime> storedAt,
      Value<DateTime> expiresAt,
      Value<String> status,
      Value<bool> isSynced,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalSampleVaultsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSampleVaultsTable> {
  $$LocalSampleVaultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inspectionId => $composableBuilder(
    column: $table.inspectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get menuName => $composableBuilder(
    column: $table.menuName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelCode => $composableBuilder(
    column: $table.labelCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSampleVaultsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSampleVaultsTable> {
  $$LocalSampleVaultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inspectionId => $composableBuilder(
    column: $table.inspectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get menuName => $composableBuilder(
    column: $table.menuName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelCode => $composableBuilder(
    column: $table.labelCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSampleVaultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSampleVaultsTable> {
  $$LocalSampleVaultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get inspectionId => $composableBuilder(
    column: $table.inspectionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schoolId =>
      $composableBuilder(column: $table.schoolId, builder: (column) => column);

  GeneratedColumn<String> get menuName =>
      $composableBuilder(column: $table.menuName, builder: (column) => column);

  GeneratedColumn<String> get labelCode =>
      $composableBuilder(column: $table.labelCode, builder: (column) => column);

  GeneratedColumn<DateTime> get storedAt =>
      $composableBuilder(column: $table.storedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalSampleVaultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSampleVaultsTable,
          LocalSampleVault,
          $$LocalSampleVaultsTableFilterComposer,
          $$LocalSampleVaultsTableOrderingComposer,
          $$LocalSampleVaultsTableAnnotationComposer,
          $$LocalSampleVaultsTableCreateCompanionBuilder,
          $$LocalSampleVaultsTableUpdateCompanionBuilder,
          (
            LocalSampleVault,
            BaseReferences<
              _$AppDatabase,
              $LocalSampleVaultsTable,
              LocalSampleVault
            >,
          ),
          LocalSampleVault,
          PrefetchHooks Function()
        > {
  $$LocalSampleVaultsTableTableManager(
    _$AppDatabase db,
    $LocalSampleVaultsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSampleVaultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSampleVaultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSampleVaultsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> inspectionId = const Value.absent(),
                Value<String> schoolId = const Value.absent(),
                Value<String> menuName = const Value.absent(),
                Value<String> labelCode = const Value.absent(),
                Value<DateTime> storedAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSampleVaultsCompanion(
                id: id,
                inspectionId: inspectionId,
                schoolId: schoolId,
                menuName: menuName,
                labelCode: labelCode,
                storedAt: storedAt,
                expiresAt: expiresAt,
                status: status,
                isSynced: isSynced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String inspectionId,
                required String schoolId,
                required String menuName,
                required String labelCode,
                required DateTime storedAt,
                required DateTime expiresAt,
                Value<String> status = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalSampleVaultsCompanion.insert(
                id: id,
                inspectionId: inspectionId,
                schoolId: schoolId,
                menuName: menuName,
                labelCode: labelCode,
                storedAt: storedAt,
                expiresAt: expiresAt,
                status: status,
                isSynced: isSynced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSampleVaultsTable, LocalSampleVault>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSampleVaultsTable,
                    LocalSampleVault
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSampleVaultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSampleVaultsTable,
      LocalSampleVault,
      $$LocalSampleVaultsTableFilterComposer,
      $$LocalSampleVaultsTableOrderingComposer,
      $$LocalSampleVaultsTableAnnotationComposer,
      $$LocalSampleVaultsTableCreateCompanionBuilder,
      $$LocalSampleVaultsTableUpdateCompanionBuilder,
      (
        LocalSampleVault,
        BaseReferences<
          _$AppDatabase,
          $LocalSampleVaultsTable,
          LocalSampleVault
        >,
      ),
      LocalSampleVault,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalSppgKeysTableTableManager get localSppgKeys =>
      $$LocalSppgKeysTableTableManager(_db, _db.localSppgKeys);
  $$LocalBmkgCacheTableTableManager get localBmkgCache =>
      $$LocalBmkgCacheTableTableManager(_db, _db.localBmkgCache);
  $$LocalSyncQueueTableTableManager get localSyncQueue =>
      $$LocalSyncQueueTableTableManager(_db, _db.localSyncQueue);
  $$LocalSampleVaultsTableTableManager get localSampleVaults =>
      $$LocalSampleVaultsTableTableManager(_db, _db.localSampleVaults);
}
