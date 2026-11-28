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

class $LocalSigningKeysTable extends LocalSigningKeys
    with TableInfo<$LocalSigningKeysTable, LocalSigningKey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSigningKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyIdMeta = const VerificationMeta('keyId');
  @override
  late final GeneratedColumn<String> keyId = GeneratedColumn<String>(
    'key_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sppgIdMeta = const VerificationMeta('sppgId');
  @override
  late final GeneratedColumn<String> sppgId = GeneratedColumn<String>(
    'sppg_id',
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
  static const VerificationMeta _deviceLabelMeta = const VerificationMeta(
    'deviceLabel',
  );
  @override
  late final GeneratedColumn<String> deviceLabel = GeneratedColumn<String>(
    'device_label',
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
  static const VerificationMeta _retiredAtMeta = const VerificationMeta(
    'retiredAt',
  );
  @override
  late final GeneratedColumn<DateTime> retiredAt = GeneratedColumn<DateTime>(
    'retired_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revokedAtMeta = const VerificationMeta(
    'revokedAt',
  );
  @override
  late final GeneratedColumn<DateTime> revokedAt = GeneratedColumn<DateTime>(
    'revoked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    keyId,
    sppgId,
    publicKeyB64,
    status,
    deviceLabel,
    createdAt,
    retiredAt,
    revokedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_signing_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSigningKey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key_id')) {
      context.handle(
        _keyIdMeta,
        keyId.isAcceptableOrUnknown(data['key_id']!, _keyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_keyIdMeta);
    }
    if (data.containsKey('sppg_id')) {
      context.handle(
        _sppgIdMeta,
        sppgId.isAcceptableOrUnknown(data['sppg_id']!, _sppgIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sppgIdMeta);
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
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('device_label')) {
      context.handle(
        _deviceLabelMeta,
        deviceLabel.isAcceptableOrUnknown(
          data['device_label']!,
          _deviceLabelMeta,
        ),
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
    if (data.containsKey('retired_at')) {
      context.handle(
        _retiredAtMeta,
        retiredAt.isAcceptableOrUnknown(data['retired_at']!, _retiredAtMeta),
      );
    }
    if (data.containsKey('revoked_at')) {
      context.handle(
        _revokedAtMeta,
        revokedAt.isAcceptableOrUnknown(data['revoked_at']!, _revokedAtMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {keyId};
  @override
  LocalSigningKey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSigningKey(
      keyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_id'],
      )!,
      sppgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sppg_id'],
      )!,
      publicKeyB64: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_key_b64'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      deviceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_label'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}retired_at'],
      ),
      revokedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}revoked_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalSigningKeysTable createAlias(String alias) {
    return $LocalSigningKeysTable(attachedDatabase, alias);
  }
}

class LocalSigningKey extends DataClass implements Insertable<LocalSigningKey> {
  final String keyId;
  final String sppgId;
  final String publicKeyB64;

  /// One of: active, retired, revoked.
  final String status;
  final String? deviceLabel;
  final DateTime createdAt;
  final DateTime? retiredAt;
  final DateTime? revokedAt;
  final DateTime updatedAt;
  const LocalSigningKey({
    required this.keyId,
    required this.sppgId,
    required this.publicKeyB64,
    required this.status,
    this.deviceLabel,
    required this.createdAt,
    this.retiredAt,
    this.revokedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key_id'] = Variable<String>(keyId);
    map['sppg_id'] = Variable<String>(sppgId);
    map['public_key_b64'] = Variable<String>(publicKeyB64);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || deviceLabel != null) {
      map['device_label'] = Variable<String>(deviceLabel);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || retiredAt != null) {
      map['retired_at'] = Variable<DateTime>(retiredAt);
    }
    if (!nullToAbsent || revokedAt != null) {
      map['revoked_at'] = Variable<DateTime>(revokedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalSigningKeysCompanion toCompanion(bool nullToAbsent) {
    return LocalSigningKeysCompanion(
      keyId: Value(keyId),
      sppgId: Value(sppgId),
      publicKeyB64: Value(publicKeyB64),
      status: Value(status),
      deviceLabel: deviceLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceLabel),
      createdAt: Value(createdAt),
      retiredAt: retiredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(retiredAt),
      revokedAt: revokedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(revokedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalSigningKey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSigningKey(
      keyId: serializer.fromJson<String>(json['keyId']),
      sppgId: serializer.fromJson<String>(json['sppgId']),
      publicKeyB64: serializer.fromJson<String>(json['publicKeyB64']),
      status: serializer.fromJson<String>(json['status']),
      deviceLabel: serializer.fromJson<String?>(json['deviceLabel']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retiredAt: serializer.fromJson<DateTime?>(json['retiredAt']),
      revokedAt: serializer.fromJson<DateTime?>(json['revokedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'keyId': serializer.toJson<String>(keyId),
      'sppgId': serializer.toJson<String>(sppgId),
      'publicKeyB64': serializer.toJson<String>(publicKeyB64),
      'status': serializer.toJson<String>(status),
      'deviceLabel': serializer.toJson<String?>(deviceLabel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retiredAt': serializer.toJson<DateTime?>(retiredAt),
      'revokedAt': serializer.toJson<DateTime?>(revokedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalSigningKey copyWith({
    String? keyId,
    String? sppgId,
    String? publicKeyB64,
    String? status,
    Value<String?> deviceLabel = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> retiredAt = const Value.absent(),
    Value<DateTime?> revokedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => LocalSigningKey(
    keyId: keyId ?? this.keyId,
    sppgId: sppgId ?? this.sppgId,
    publicKeyB64: publicKeyB64 ?? this.publicKeyB64,
    status: status ?? this.status,
    deviceLabel: deviceLabel.present ? deviceLabel.value : this.deviceLabel,
    createdAt: createdAt ?? this.createdAt,
    retiredAt: retiredAt.present ? retiredAt.value : this.retiredAt,
    revokedAt: revokedAt.present ? revokedAt.value : this.revokedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalSigningKey copyWithCompanion(LocalSigningKeysCompanion data) {
    return LocalSigningKey(
      keyId: data.keyId.present ? data.keyId.value : this.keyId,
      sppgId: data.sppgId.present ? data.sppgId.value : this.sppgId,
      publicKeyB64: data.publicKeyB64.present
          ? data.publicKeyB64.value
          : this.publicKeyB64,
      status: data.status.present ? data.status.value : this.status,
      deviceLabel: data.deviceLabel.present
          ? data.deviceLabel.value
          : this.deviceLabel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retiredAt: data.retiredAt.present ? data.retiredAt.value : this.retiredAt,
      revokedAt: data.revokedAt.present ? data.revokedAt.value : this.revokedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSigningKey(')
          ..write('keyId: $keyId, ')
          ..write('sppgId: $sppgId, ')
          ..write('publicKeyB64: $publicKeyB64, ')
          ..write('status: $status, ')
          ..write('deviceLabel: $deviceLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('retiredAt: $retiredAt, ')
          ..write('revokedAt: $revokedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    keyId,
    sppgId,
    publicKeyB64,
    status,
    deviceLabel,
    createdAt,
    retiredAt,
    revokedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSigningKey &&
          other.keyId == this.keyId &&
          other.sppgId == this.sppgId &&
          other.publicKeyB64 == this.publicKeyB64 &&
          other.status == this.status &&
          other.deviceLabel == this.deviceLabel &&
          other.createdAt == this.createdAt &&
          other.retiredAt == this.retiredAt &&
          other.revokedAt == this.revokedAt &&
          other.updatedAt == this.updatedAt);
}

class LocalSigningKeysCompanion extends UpdateCompanion<LocalSigningKey> {
  final Value<String> keyId;
  final Value<String> sppgId;
  final Value<String> publicKeyB64;
  final Value<String> status;
  final Value<String?> deviceLabel;
  final Value<DateTime> createdAt;
  final Value<DateTime?> retiredAt;
  final Value<DateTime?> revokedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalSigningKeysCompanion({
    this.keyId = const Value.absent(),
    this.sppgId = const Value.absent(),
    this.publicKeyB64 = const Value.absent(),
    this.status = const Value.absent(),
    this.deviceLabel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retiredAt = const Value.absent(),
    this.revokedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSigningKeysCompanion.insert({
    required String keyId,
    required String sppgId,
    required String publicKeyB64,
    this.status = const Value.absent(),
    this.deviceLabel = const Value.absent(),
    required DateTime createdAt,
    this.retiredAt = const Value.absent(),
    this.revokedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : keyId = Value(keyId),
       sppgId = Value(sppgId),
       publicKeyB64 = Value(publicKeyB64),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalSigningKey> custom({
    Expression<String>? keyId,
    Expression<String>? sppgId,
    Expression<String>? publicKeyB64,
    Expression<String>? status,
    Expression<String>? deviceLabel,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? retiredAt,
    Expression<DateTime>? revokedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (keyId != null) 'key_id': keyId,
      if (sppgId != null) 'sppg_id': sppgId,
      if (publicKeyB64 != null) 'public_key_b64': publicKeyB64,
      if (status != null) 'status': status,
      if (deviceLabel != null) 'device_label': deviceLabel,
      if (createdAt != null) 'created_at': createdAt,
      if (retiredAt != null) 'retired_at': retiredAt,
      if (revokedAt != null) 'revoked_at': revokedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSigningKeysCompanion copyWith({
    Value<String>? keyId,
    Value<String>? sppgId,
    Value<String>? publicKeyB64,
    Value<String>? status,
    Value<String?>? deviceLabel,
    Value<DateTime>? createdAt,
    Value<DateTime?>? retiredAt,
    Value<DateTime?>? revokedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalSigningKeysCompanion(
      keyId: keyId ?? this.keyId,
      sppgId: sppgId ?? this.sppgId,
      publicKeyB64: publicKeyB64 ?? this.publicKeyB64,
      status: status ?? this.status,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      createdAt: createdAt ?? this.createdAt,
      retiredAt: retiredAt ?? this.retiredAt,
      revokedAt: revokedAt ?? this.revokedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (keyId.present) {
      map['key_id'] = Variable<String>(keyId.value);
    }
    if (sppgId.present) {
      map['sppg_id'] = Variable<String>(sppgId.value);
    }
    if (publicKeyB64.present) {
      map['public_key_b64'] = Variable<String>(publicKeyB64.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (deviceLabel.present) {
      map['device_label'] = Variable<String>(deviceLabel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retiredAt.present) {
      map['retired_at'] = Variable<DateTime>(retiredAt.value);
    }
    if (revokedAt.present) {
      map['revoked_at'] = Variable<DateTime>(revokedAt.value);
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
    return (StringBuffer('LocalSigningKeysCompanion(')
          ..write('keyId: $keyId, ')
          ..write('sppgId: $sppgId, ')
          ..write('publicKeyB64: $publicKeyB64, ')
          ..write('status: $status, ')
          ..write('deviceLabel: $deviceLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('retiredAt: $retiredAt, ')
          ..write('revokedAt: $revokedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalInstitutionMembersTable extends LocalInstitutionMembers
    with TableInfo<$LocalInstitutionMembersTable, LocalInstitutionMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalInstitutionMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _institutionTypeMeta = const VerificationMeta(
    'institutionType',
  );
  @override
  late final GeneratedColumn<String> institutionType = GeneratedColumn<String>(
    'institution_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _institutionIdMeta = const VerificationMeta(
    'institutionId',
  );
  @override
  late final GeneratedColumn<String> institutionId = GeneratedColumn<String>(
    'institution_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memberNameMeta = const VerificationMeta(
    'memberName',
  );
  @override
  late final GeneratedColumn<String> memberName = GeneratedColumn<String>(
    'member_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberEmailMeta = const VerificationMeta(
    'memberEmail',
  );
  @override
  late final GeneratedColumn<String> memberEmail = GeneratedColumn<String>(
    'member_email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
    institutionType,
    institutionId,
    userId,
    memberName,
    memberEmail,
    role,
    isActive,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_institution_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalInstitutionMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('institution_type')) {
      context.handle(
        _institutionTypeMeta,
        institutionType.isAcceptableOrUnknown(
          data['institution_type']!,
          _institutionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_institutionTypeMeta);
    }
    if (data.containsKey('institution_id')) {
      context.handle(
        _institutionIdMeta,
        institutionId.isAcceptableOrUnknown(
          data['institution_id']!,
          _institutionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_institutionIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('member_name')) {
      context.handle(
        _memberNameMeta,
        memberName.isAcceptableOrUnknown(data['member_name']!, _memberNameMeta),
      );
    } else if (isInserting) {
      context.missing(_memberNameMeta);
    }
    if (data.containsKey('member_email')) {
      context.handle(
        _memberEmailMeta,
        memberEmail.isAcceptableOrUnknown(
          data['member_email']!,
          _memberEmailMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_memberEmailMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
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
  LocalInstitutionMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalInstitutionMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      institutionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution_type'],
      )!,
      institutionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      memberName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_name'],
      )!,
      memberEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_email'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
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
  $LocalInstitutionMembersTable createAlias(String alias) {
    return $LocalInstitutionMembersTable(attachedDatabase, alias);
  }
}

class LocalInstitutionMember extends DataClass
    implements Insertable<LocalInstitutionMember> {
  final String id;

  /// One of: sppg, school.
  final String institutionType;
  final String institutionId;
  final String? userId;
  final String memberName;
  final String memberEmail;

  /// One of: admin, staff, courier.
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalInstitutionMember({
    required this.id,
    required this.institutionType,
    required this.institutionId,
    this.userId,
    required this.memberName,
    required this.memberEmail,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['institution_type'] = Variable<String>(institutionType);
    map['institution_id'] = Variable<String>(institutionId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['member_name'] = Variable<String>(memberName);
    map['member_email'] = Variable<String>(memberEmail);
    map['role'] = Variable<String>(role);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalInstitutionMembersCompanion toCompanion(bool nullToAbsent) {
    return LocalInstitutionMembersCompanion(
      id: Value(id),
      institutionType: Value(institutionType),
      institutionId: Value(institutionId),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      memberName: Value(memberName),
      memberEmail: Value(memberEmail),
      role: Value(role),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalInstitutionMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalInstitutionMember(
      id: serializer.fromJson<String>(json['id']),
      institutionType: serializer.fromJson<String>(json['institutionType']),
      institutionId: serializer.fromJson<String>(json['institutionId']),
      userId: serializer.fromJson<String?>(json['userId']),
      memberName: serializer.fromJson<String>(json['memberName']),
      memberEmail: serializer.fromJson<String>(json['memberEmail']),
      role: serializer.fromJson<String>(json['role']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'institutionType': serializer.toJson<String>(institutionType),
      'institutionId': serializer.toJson<String>(institutionId),
      'userId': serializer.toJson<String?>(userId),
      'memberName': serializer.toJson<String>(memberName),
      'memberEmail': serializer.toJson<String>(memberEmail),
      'role': serializer.toJson<String>(role),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalInstitutionMember copyWith({
    String? id,
    String? institutionType,
    String? institutionId,
    Value<String?> userId = const Value.absent(),
    String? memberName,
    String? memberEmail,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalInstitutionMember(
    id: id ?? this.id,
    institutionType: institutionType ?? this.institutionType,
    institutionId: institutionId ?? this.institutionId,
    userId: userId.present ? userId.value : this.userId,
    memberName: memberName ?? this.memberName,
    memberEmail: memberEmail ?? this.memberEmail,
    role: role ?? this.role,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalInstitutionMember copyWithCompanion(
    LocalInstitutionMembersCompanion data,
  ) {
    return LocalInstitutionMember(
      id: data.id.present ? data.id.value : this.id,
      institutionType: data.institutionType.present
          ? data.institutionType.value
          : this.institutionType,
      institutionId: data.institutionId.present
          ? data.institutionId.value
          : this.institutionId,
      userId: data.userId.present ? data.userId.value : this.userId,
      memberName: data.memberName.present
          ? data.memberName.value
          : this.memberName,
      memberEmail: data.memberEmail.present
          ? data.memberEmail.value
          : this.memberEmail,
      role: data.role.present ? data.role.value : this.role,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalInstitutionMember(')
          ..write('id: $id, ')
          ..write('institutionType: $institutionType, ')
          ..write('institutionId: $institutionId, ')
          ..write('userId: $userId, ')
          ..write('memberName: $memberName, ')
          ..write('memberEmail: $memberEmail, ')
          ..write('role: $role, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    institutionType,
    institutionId,
    userId,
    memberName,
    memberEmail,
    role,
    isActive,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalInstitutionMember &&
          other.id == this.id &&
          other.institutionType == this.institutionType &&
          other.institutionId == this.institutionId &&
          other.userId == this.userId &&
          other.memberName == this.memberName &&
          other.memberEmail == this.memberEmail &&
          other.role == this.role &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalInstitutionMembersCompanion
    extends UpdateCompanion<LocalInstitutionMember> {
  final Value<String> id;
  final Value<String> institutionType;
  final Value<String> institutionId;
  final Value<String?> userId;
  final Value<String> memberName;
  final Value<String> memberEmail;
  final Value<String> role;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalInstitutionMembersCompanion({
    this.id = const Value.absent(),
    this.institutionType = const Value.absent(),
    this.institutionId = const Value.absent(),
    this.userId = const Value.absent(),
    this.memberName = const Value.absent(),
    this.memberEmail = const Value.absent(),
    this.role = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalInstitutionMembersCompanion.insert({
    required String id,
    required String institutionType,
    required String institutionId,
    this.userId = const Value.absent(),
    required String memberName,
    required String memberEmail,
    required String role,
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       institutionType = Value(institutionType),
       institutionId = Value(institutionId),
       memberName = Value(memberName),
       memberEmail = Value(memberEmail),
       role = Value(role),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalInstitutionMember> custom({
    Expression<String>? id,
    Expression<String>? institutionType,
    Expression<String>? institutionId,
    Expression<String>? userId,
    Expression<String>? memberName,
    Expression<String>? memberEmail,
    Expression<String>? role,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (institutionType != null) 'institution_type': institutionType,
      if (institutionId != null) 'institution_id': institutionId,
      if (userId != null) 'user_id': userId,
      if (memberName != null) 'member_name': memberName,
      if (memberEmail != null) 'member_email': memberEmail,
      if (role != null) 'role': role,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalInstitutionMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? institutionType,
    Value<String>? institutionId,
    Value<String?>? userId,
    Value<String>? memberName,
    Value<String>? memberEmail,
    Value<String>? role,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalInstitutionMembersCompanion(
      id: id ?? this.id,
      institutionType: institutionType ?? this.institutionType,
      institutionId: institutionId ?? this.institutionId,
      userId: userId ?? this.userId,
      memberName: memberName ?? this.memberName,
      memberEmail: memberEmail ?? this.memberEmail,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (institutionType.present) {
      map['institution_type'] = Variable<String>(institutionType.value);
    }
    if (institutionId.present) {
      map['institution_id'] = Variable<String>(institutionId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (memberName.present) {
      map['member_name'] = Variable<String>(memberName.value);
    }
    if (memberEmail.present) {
      map['member_email'] = Variable<String>(memberEmail.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('LocalInstitutionMembersCompanion(')
          ..write('id: $id, ')
          ..write('institutionType: $institutionType, ')
          ..write('institutionId: $institutionId, ')
          ..write('userId: $userId, ')
          ..write('memberName: $memberName, ')
          ..write('memberEmail: $memberEmail, ')
          ..write('role: $role, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSchoolAllergensTable extends LocalSchoolAllergens
    with TableInfo<$LocalSchoolAllergensTable, LocalSchoolAllergen> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSchoolAllergensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _allergenTagMeta = const VerificationMeta(
    'allergenTag',
  );
  @override
  late final GeneratedColumn<String> allergenTag = GeneratedColumn<String>(
    'allergen_tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studentCountMeta = const VerificationMeta(
    'studentCount',
  );
  @override
  late final GeneratedColumn<int> studentCount = GeneratedColumn<int>(
    'student_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _severityLevelMeta = const VerificationMeta(
    'severityLevel',
  );
  @override
  late final GeneratedColumn<String> severityLevel = GeneratedColumn<String>(
    'severity_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('moderate'),
  );
  static const VerificationMeta _handlingNoteMeta = const VerificationMeta(
    'handlingNote',
  );
  @override
  late final GeneratedColumn<String> handlingNote = GeneratedColumn<String>(
    'handling_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    schoolId,
    allergenTag,
    studentCount,
    severityLevel,
    handlingNote,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_school_allergens';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSchoolAllergen> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('school_id')) {
      context.handle(
        _schoolIdMeta,
        schoolId.isAcceptableOrUnknown(data['school_id']!, _schoolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_schoolIdMeta);
    }
    if (data.containsKey('allergen_tag')) {
      context.handle(
        _allergenTagMeta,
        allergenTag.isAcceptableOrUnknown(
          data['allergen_tag']!,
          _allergenTagMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allergenTagMeta);
    }
    if (data.containsKey('student_count')) {
      context.handle(
        _studentCountMeta,
        studentCount.isAcceptableOrUnknown(
          data['student_count']!,
          _studentCountMeta,
        ),
      );
    }
    if (data.containsKey('severity_level')) {
      context.handle(
        _severityLevelMeta,
        severityLevel.isAcceptableOrUnknown(
          data['severity_level']!,
          _severityLevelMeta,
        ),
      );
    }
    if (data.containsKey('handling_note')) {
      context.handle(
        _handlingNoteMeta,
        handlingNote.isAcceptableOrUnknown(
          data['handling_note']!,
          _handlingNoteMeta,
        ),
      );
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
  LocalSchoolAllergen map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSchoolAllergen(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      schoolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_id'],
      )!,
      allergenTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allergen_tag'],
      )!,
      studentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}student_count'],
      )!,
      severityLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}severity_level'],
      )!,
      handlingNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}handling_note'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalSchoolAllergensTable createAlias(String alias) {
    return $LocalSchoolAllergensTable(attachedDatabase, alias);
  }
}

class LocalSchoolAllergen extends DataClass
    implements Insertable<LocalSchoolAllergen> {
  final String id;
  final String schoolId;
  final String allergenTag;
  final int studentCount;

  /// One of: mild, moderate, severe.
  final String severityLevel;
  final String? handlingNote;
  final DateTime updatedAt;
  const LocalSchoolAllergen({
    required this.id,
    required this.schoolId,
    required this.allergenTag,
    required this.studentCount,
    required this.severityLevel,
    this.handlingNote,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['school_id'] = Variable<String>(schoolId);
    map['allergen_tag'] = Variable<String>(allergenTag);
    map['student_count'] = Variable<int>(studentCount);
    map['severity_level'] = Variable<String>(severityLevel);
    if (!nullToAbsent || handlingNote != null) {
      map['handling_note'] = Variable<String>(handlingNote);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalSchoolAllergensCompanion toCompanion(bool nullToAbsent) {
    return LocalSchoolAllergensCompanion(
      id: Value(id),
      schoolId: Value(schoolId),
      allergenTag: Value(allergenTag),
      studentCount: Value(studentCount),
      severityLevel: Value(severityLevel),
      handlingNote: handlingNote == null && nullToAbsent
          ? const Value.absent()
          : Value(handlingNote),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalSchoolAllergen.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSchoolAllergen(
      id: serializer.fromJson<String>(json['id']),
      schoolId: serializer.fromJson<String>(json['schoolId']),
      allergenTag: serializer.fromJson<String>(json['allergenTag']),
      studentCount: serializer.fromJson<int>(json['studentCount']),
      severityLevel: serializer.fromJson<String>(json['severityLevel']),
      handlingNote: serializer.fromJson<String?>(json['handlingNote']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'schoolId': serializer.toJson<String>(schoolId),
      'allergenTag': serializer.toJson<String>(allergenTag),
      'studentCount': serializer.toJson<int>(studentCount),
      'severityLevel': serializer.toJson<String>(severityLevel),
      'handlingNote': serializer.toJson<String?>(handlingNote),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalSchoolAllergen copyWith({
    String? id,
    String? schoolId,
    String? allergenTag,
    int? studentCount,
    String? severityLevel,
    Value<String?> handlingNote = const Value.absent(),
    DateTime? updatedAt,
  }) => LocalSchoolAllergen(
    id: id ?? this.id,
    schoolId: schoolId ?? this.schoolId,
    allergenTag: allergenTag ?? this.allergenTag,
    studentCount: studentCount ?? this.studentCount,
    severityLevel: severityLevel ?? this.severityLevel,
    handlingNote: handlingNote.present ? handlingNote.value : this.handlingNote,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalSchoolAllergen copyWithCompanion(LocalSchoolAllergensCompanion data) {
    return LocalSchoolAllergen(
      id: data.id.present ? data.id.value : this.id,
      schoolId: data.schoolId.present ? data.schoolId.value : this.schoolId,
      allergenTag: data.allergenTag.present
          ? data.allergenTag.value
          : this.allergenTag,
      studentCount: data.studentCount.present
          ? data.studentCount.value
          : this.studentCount,
      severityLevel: data.severityLevel.present
          ? data.severityLevel.value
          : this.severityLevel,
      handlingNote: data.handlingNote.present
          ? data.handlingNote.value
          : this.handlingNote,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSchoolAllergen(')
          ..write('id: $id, ')
          ..write('schoolId: $schoolId, ')
          ..write('allergenTag: $allergenTag, ')
          ..write('studentCount: $studentCount, ')
          ..write('severityLevel: $severityLevel, ')
          ..write('handlingNote: $handlingNote, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    schoolId,
    allergenTag,
    studentCount,
    severityLevel,
    handlingNote,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSchoolAllergen &&
          other.id == this.id &&
          other.schoolId == this.schoolId &&
          other.allergenTag == this.allergenTag &&
          other.studentCount == this.studentCount &&
          other.severityLevel == this.severityLevel &&
          other.handlingNote == this.handlingNote &&
          other.updatedAt == this.updatedAt);
}

class LocalSchoolAllergensCompanion
    extends UpdateCompanion<LocalSchoolAllergen> {
  final Value<String> id;
  final Value<String> schoolId;
  final Value<String> allergenTag;
  final Value<int> studentCount;
  final Value<String> severityLevel;
  final Value<String?> handlingNote;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalSchoolAllergensCompanion({
    this.id = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.allergenTag = const Value.absent(),
    this.studentCount = const Value.absent(),
    this.severityLevel = const Value.absent(),
    this.handlingNote = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSchoolAllergensCompanion.insert({
    required String id,
    required String schoolId,
    required String allergenTag,
    this.studentCount = const Value.absent(),
    this.severityLevel = const Value.absent(),
    this.handlingNote = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       schoolId = Value(schoolId),
       allergenTag = Value(allergenTag),
       updatedAt = Value(updatedAt);
  static Insertable<LocalSchoolAllergen> custom({
    Expression<String>? id,
    Expression<String>? schoolId,
    Expression<String>? allergenTag,
    Expression<int>? studentCount,
    Expression<String>? severityLevel,
    Expression<String>? handlingNote,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schoolId != null) 'school_id': schoolId,
      if (allergenTag != null) 'allergen_tag': allergenTag,
      if (studentCount != null) 'student_count': studentCount,
      if (severityLevel != null) 'severity_level': severityLevel,
      if (handlingNote != null) 'handling_note': handlingNote,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSchoolAllergensCompanion copyWith({
    Value<String>? id,
    Value<String>? schoolId,
    Value<String>? allergenTag,
    Value<int>? studentCount,
    Value<String>? severityLevel,
    Value<String?>? handlingNote,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalSchoolAllergensCompanion(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      allergenTag: allergenTag ?? this.allergenTag,
      studentCount: studentCount ?? this.studentCount,
      severityLevel: severityLevel ?? this.severityLevel,
      handlingNote: handlingNote ?? this.handlingNote,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (schoolId.present) {
      map['school_id'] = Variable<String>(schoolId.value);
    }
    if (allergenTag.present) {
      map['allergen_tag'] = Variable<String>(allergenTag.value);
    }
    if (studentCount.present) {
      map['student_count'] = Variable<int>(studentCount.value);
    }
    if (severityLevel.present) {
      map['severity_level'] = Variable<String>(severityLevel.value);
    }
    if (handlingNote.present) {
      map['handling_note'] = Variable<String>(handlingNote.value);
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
    return (StringBuffer('LocalSchoolAllergensCompanion(')
          ..write('id: $id, ')
          ..write('schoolId: $schoolId, ')
          ..write('allergenTag: $allergenTag, ')
          ..write('studentCount: $studentCount, ')
          ..write('severityLevel: $severityLevel, ')
          ..write('handlingNote: $handlingNote, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTraceabilityDraftsTable extends LocalTraceabilityDrafts
    with TableInfo<$LocalTraceabilityDraftsTable, LocalTraceabilityDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTraceabilityDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordTypeMeta = const VerificationMeta(
    'recordType',
  );
  @override
  late final GeneratedColumn<String> recordType = GeneratedColumn<String>(
    'record_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _institutionIdMeta = const VerificationMeta(
    'institutionId',
  );
  @override
  late final GeneratedColumn<String> institutionId = GeneratedColumn<String>(
    'institution_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchIdMeta = const VerificationMeta(
    'batchId',
  );
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
    'batch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    recordType,
    institutionId,
    batchId,
    payloadJson,
    isSynced,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_traceability_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTraceabilityDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('record_type')) {
      context.handle(
        _recordTypeMeta,
        recordType.isAcceptableOrUnknown(data['record_type']!, _recordTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_recordTypeMeta);
    }
    if (data.containsKey('institution_id')) {
      context.handle(
        _institutionIdMeta,
        institutionId.isAcceptableOrUnknown(
          data['institution_id']!,
          _institutionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_institutionIdMeta);
    }
    if (data.containsKey('batch_id')) {
      context.handle(
        _batchIdMeta,
        batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta),
      );
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
  LocalTraceabilityDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTraceabilityDraft(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recordType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_type'],
      )!,
      institutionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution_id'],
      )!,
      batchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_id'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
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
  $LocalTraceabilityDraftsTable createAlias(String alias) {
    return $LocalTraceabilityDraftsTable(attachedDatabase, alias);
  }
}

class LocalTraceabilityDraft extends DataClass
    implements Insertable<LocalTraceabilityDraft> {
  final String id;

  /// One of: ingredient_log, transit_handover, tray_return, alert_resolution.
  final String recordType;
  final String institutionId;
  final String? batchId;
  final String payloadJson;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalTraceabilityDraft({
    required this.id,
    required this.recordType,
    required this.institutionId,
    this.batchId,
    required this.payloadJson,
    required this.isSynced,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['record_type'] = Variable<String>(recordType);
    map['institution_id'] = Variable<String>(institutionId);
    if (!nullToAbsent || batchId != null) {
      map['batch_id'] = Variable<String>(batchId);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['is_synced'] = Variable<bool>(isSynced);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalTraceabilityDraftsCompanion toCompanion(bool nullToAbsent) {
    return LocalTraceabilityDraftsCompanion(
      id: Value(id),
      recordType: Value(recordType),
      institutionId: Value(institutionId),
      batchId: batchId == null && nullToAbsent
          ? const Value.absent()
          : Value(batchId),
      payloadJson: Value(payloadJson),
      isSynced: Value(isSynced),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalTraceabilityDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTraceabilityDraft(
      id: serializer.fromJson<String>(json['id']),
      recordType: serializer.fromJson<String>(json['recordType']),
      institutionId: serializer.fromJson<String>(json['institutionId']),
      batchId: serializer.fromJson<String?>(json['batchId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recordType': serializer.toJson<String>(recordType),
      'institutionId': serializer.toJson<String>(institutionId),
      'batchId': serializer.toJson<String?>(batchId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'isSynced': serializer.toJson<bool>(isSynced),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalTraceabilityDraft copyWith({
    String? id,
    String? recordType,
    String? institutionId,
    Value<String?> batchId = const Value.absent(),
    String? payloadJson,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalTraceabilityDraft(
    id: id ?? this.id,
    recordType: recordType ?? this.recordType,
    institutionId: institutionId ?? this.institutionId,
    batchId: batchId.present ? batchId.value : this.batchId,
    payloadJson: payloadJson ?? this.payloadJson,
    isSynced: isSynced ?? this.isSynced,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalTraceabilityDraft copyWithCompanion(
    LocalTraceabilityDraftsCompanion data,
  ) {
    return LocalTraceabilityDraft(
      id: data.id.present ? data.id.value : this.id,
      recordType: data.recordType.present
          ? data.recordType.value
          : this.recordType,
      institutionId: data.institutionId.present
          ? data.institutionId.value
          : this.institutionId,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTraceabilityDraft(')
          ..write('id: $id, ')
          ..write('recordType: $recordType, ')
          ..write('institutionId: $institutionId, ')
          ..write('batchId: $batchId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('isSynced: $isSynced, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordType,
    institutionId,
    batchId,
    payloadJson,
    isSynced,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTraceabilityDraft &&
          other.id == this.id &&
          other.recordType == this.recordType &&
          other.institutionId == this.institutionId &&
          other.batchId == this.batchId &&
          other.payloadJson == this.payloadJson &&
          other.isSynced == this.isSynced &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalTraceabilityDraftsCompanion
    extends UpdateCompanion<LocalTraceabilityDraft> {
  final Value<String> id;
  final Value<String> recordType;
  final Value<String> institutionId;
  final Value<String?> batchId;
  final Value<String> payloadJson;
  final Value<bool> isSynced;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalTraceabilityDraftsCompanion({
    this.id = const Value.absent(),
    this.recordType = const Value.absent(),
    this.institutionId = const Value.absent(),
    this.batchId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTraceabilityDraftsCompanion.insert({
    required String id,
    required String recordType,
    required String institutionId,
    this.batchId = const Value.absent(),
    required String payloadJson,
    this.isSynced = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recordType = Value(recordType),
       institutionId = Value(institutionId),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalTraceabilityDraft> custom({
    Expression<String>? id,
    Expression<String>? recordType,
    Expression<String>? institutionId,
    Expression<String>? batchId,
    Expression<String>? payloadJson,
    Expression<bool>? isSynced,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordType != null) 'record_type': recordType,
      if (institutionId != null) 'institution_id': institutionId,
      if (batchId != null) 'batch_id': batchId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (isSynced != null) 'is_synced': isSynced,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTraceabilityDraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? recordType,
    Value<String>? institutionId,
    Value<String?>? batchId,
    Value<String>? payloadJson,
    Value<bool>? isSynced,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalTraceabilityDraftsCompanion(
      id: id ?? this.id,
      recordType: recordType ?? this.recordType,
      institutionId: institutionId ?? this.institutionId,
      batchId: batchId ?? this.batchId,
      payloadJson: payloadJson ?? this.payloadJson,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recordType.present) {
      map['record_type'] = Variable<String>(recordType.value);
    }
    if (institutionId.present) {
      map['institution_id'] = Variable<String>(institutionId.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('LocalTraceabilityDraftsCompanion(')
          ..write('id: $id, ')
          ..write('recordType: $recordType, ')
          ..write('institutionId: $institutionId, ')
          ..write('batchId: $batchId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('isSynced: $isSynced, ')
          ..write('createdAt: $createdAt, ')
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
  late final $LocalSigningKeysTable localSigningKeys = $LocalSigningKeysTable(
    this,
  );
  late final $LocalInstitutionMembersTable localInstitutionMembers =
      $LocalInstitutionMembersTable(this);
  late final $LocalSchoolAllergensTable localSchoolAllergens =
      $LocalSchoolAllergensTable(this);
  late final $LocalTraceabilityDraftsTable localTraceabilityDrafts =
      $LocalTraceabilityDraftsTable(this);
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
    localSigningKeys,
    localInstitutionMembers,
    localSchoolAllergens,
    localTraceabilityDrafts,
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
typedef $$LocalSigningKeysTableCreateCompanionBuilder =
    LocalSigningKeysCompanion Function({
      required String keyId,
      required String sppgId,
      required String publicKeyB64,
      Value<String> status,
      Value<String?> deviceLabel,
      required DateTime createdAt,
      Value<DateTime?> retiredAt,
      Value<DateTime?> revokedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalSigningKeysTableUpdateCompanionBuilder =
    LocalSigningKeysCompanion Function({
      Value<String> keyId,
      Value<String> sppgId,
      Value<String> publicKeyB64,
      Value<String> status,
      Value<String?> deviceLabel,
      Value<DateTime> createdAt,
      Value<DateTime?> retiredAt,
      Value<DateTime?> revokedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalSigningKeysTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSigningKeysTable> {
  $$LocalSigningKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get keyId => $composableBuilder(
    column: $table.keyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sppgId => $composableBuilder(
    column: $table.sppgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicKeyB64 => $composableBuilder(
    column: $table.publicKeyB64,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get retiredAt => $composableBuilder(
    column: $table.retiredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get revokedAt => $composableBuilder(
    column: $table.revokedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSigningKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSigningKeysTable> {
  $$LocalSigningKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get keyId => $composableBuilder(
    column: $table.keyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sppgId => $composableBuilder(
    column: $table.sppgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicKeyB64 => $composableBuilder(
    column: $table.publicKeyB64,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get retiredAt => $composableBuilder(
    column: $table.retiredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get revokedAt => $composableBuilder(
    column: $table.revokedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSigningKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSigningKeysTable> {
  $$LocalSigningKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get keyId =>
      $composableBuilder(column: $table.keyId, builder: (column) => column);

  GeneratedColumn<String> get sppgId =>
      $composableBuilder(column: $table.sppgId, builder: (column) => column);

  GeneratedColumn<String> get publicKeyB64 => $composableBuilder(
    column: $table.publicKeyB64,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get deviceLabel => $composableBuilder(
    column: $table.deviceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get retiredAt =>
      $composableBuilder(column: $table.retiredAt, builder: (column) => column);

  GeneratedColumn<DateTime> get revokedAt =>
      $composableBuilder(column: $table.revokedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalSigningKeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSigningKeysTable,
          LocalSigningKey,
          $$LocalSigningKeysTableFilterComposer,
          $$LocalSigningKeysTableOrderingComposer,
          $$LocalSigningKeysTableAnnotationComposer,
          $$LocalSigningKeysTableCreateCompanionBuilder,
          $$LocalSigningKeysTableUpdateCompanionBuilder,
          (
            LocalSigningKey,
            BaseReferences<
              _$AppDatabase,
              $LocalSigningKeysTable,
              LocalSigningKey
            >,
          ),
          LocalSigningKey,
          PrefetchHooks Function()
        > {
  $$LocalSigningKeysTableTableManager(
    _$AppDatabase db,
    $LocalSigningKeysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSigningKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSigningKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSigningKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> keyId = const Value.absent(),
                Value<String> sppgId = const Value.absent(),
                Value<String> publicKeyB64 = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> deviceLabel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> retiredAt = const Value.absent(),
                Value<DateTime?> revokedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSigningKeysCompanion(
                keyId: keyId,
                sppgId: sppgId,
                publicKeyB64: publicKeyB64,
                status: status,
                deviceLabel: deviceLabel,
                createdAt: createdAt,
                retiredAt: retiredAt,
                revokedAt: revokedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String keyId,
                required String sppgId,
                required String publicKeyB64,
                Value<String> status = const Value.absent(),
                Value<String?> deviceLabel = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> retiredAt = const Value.absent(),
                Value<DateTime?> revokedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalSigningKeysCompanion.insert(
                keyId: keyId,
                sppgId: sppgId,
                publicKeyB64: publicKeyB64,
                status: status,
                deviceLabel: deviceLabel,
                createdAt: createdAt,
                retiredAt: retiredAt,
                revokedAt: revokedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSigningKeysTable, LocalSigningKey>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSigningKeysTable,
                    LocalSigningKey
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSigningKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSigningKeysTable,
      LocalSigningKey,
      $$LocalSigningKeysTableFilterComposer,
      $$LocalSigningKeysTableOrderingComposer,
      $$LocalSigningKeysTableAnnotationComposer,
      $$LocalSigningKeysTableCreateCompanionBuilder,
      $$LocalSigningKeysTableUpdateCompanionBuilder,
      (
        LocalSigningKey,
        BaseReferences<_$AppDatabase, $LocalSigningKeysTable, LocalSigningKey>,
      ),
      LocalSigningKey,
      PrefetchHooks Function()
    >;
typedef $$LocalInstitutionMembersTableCreateCompanionBuilder =
    LocalInstitutionMembersCompanion Function({
      required String id,
      required String institutionType,
      required String institutionId,
      Value<String?> userId,
      required String memberName,
      required String memberEmail,
      required String role,
      Value<bool> isActive,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalInstitutionMembersTableUpdateCompanionBuilder =
    LocalInstitutionMembersCompanion Function({
      Value<String> id,
      Value<String> institutionType,
      Value<String> institutionId,
      Value<String?> userId,
      Value<String> memberName,
      Value<String> memberEmail,
      Value<String> role,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalInstitutionMembersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalInstitutionMembersTable> {
  $$LocalInstitutionMembersTableFilterComposer({
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

  ColumnFilters<String> get institutionType => $composableBuilder(
    column: $table.institutionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberName => $composableBuilder(
    column: $table.memberName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberEmail => $composableBuilder(
    column: $table.memberEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

class $$LocalInstitutionMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalInstitutionMembersTable> {
  $$LocalInstitutionMembersTableOrderingComposer({
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

  ColumnOrderings<String> get institutionType => $composableBuilder(
    column: $table.institutionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberName => $composableBuilder(
    column: $table.memberName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberEmail => $composableBuilder(
    column: $table.memberEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

class $$LocalInstitutionMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalInstitutionMembersTable> {
  $$LocalInstitutionMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get institutionType => $composableBuilder(
    column: $table.institutionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get memberName => $composableBuilder(
    column: $table.memberName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memberEmail => $composableBuilder(
    column: $table.memberEmail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalInstitutionMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalInstitutionMembersTable,
          LocalInstitutionMember,
          $$LocalInstitutionMembersTableFilterComposer,
          $$LocalInstitutionMembersTableOrderingComposer,
          $$LocalInstitutionMembersTableAnnotationComposer,
          $$LocalInstitutionMembersTableCreateCompanionBuilder,
          $$LocalInstitutionMembersTableUpdateCompanionBuilder,
          (
            LocalInstitutionMember,
            BaseReferences<
              _$AppDatabase,
              $LocalInstitutionMembersTable,
              LocalInstitutionMember
            >,
          ),
          LocalInstitutionMember,
          PrefetchHooks Function()
        > {
  $$LocalInstitutionMembersTableTableManager(
    _$AppDatabase db,
    $LocalInstitutionMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalInstitutionMembersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalInstitutionMembersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalInstitutionMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> institutionType = const Value.absent(),
                Value<String> institutionId = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> memberName = const Value.absent(),
                Value<String> memberEmail = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalInstitutionMembersCompanion(
                id: id,
                institutionType: institutionType,
                institutionId: institutionId,
                userId: userId,
                memberName: memberName,
                memberEmail: memberEmail,
                role: role,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String institutionType,
                required String institutionId,
                Value<String?> userId = const Value.absent(),
                required String memberName,
                required String memberEmail,
                required String role,
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalInstitutionMembersCompanion.insert(
                id: id,
                institutionType: institutionType,
                institutionId: institutionId,
                userId: userId,
                memberName: memberName,
                memberEmail: memberEmail,
                role: role,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalInstitutionMembersTable,
                    LocalInstitutionMember
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalInstitutionMembersTable,
                    LocalInstitutionMember
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalInstitutionMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalInstitutionMembersTable,
      LocalInstitutionMember,
      $$LocalInstitutionMembersTableFilterComposer,
      $$LocalInstitutionMembersTableOrderingComposer,
      $$LocalInstitutionMembersTableAnnotationComposer,
      $$LocalInstitutionMembersTableCreateCompanionBuilder,
      $$LocalInstitutionMembersTableUpdateCompanionBuilder,
      (
        LocalInstitutionMember,
        BaseReferences<
          _$AppDatabase,
          $LocalInstitutionMembersTable,
          LocalInstitutionMember
        >,
      ),
      LocalInstitutionMember,
      PrefetchHooks Function()
    >;
typedef $$LocalSchoolAllergensTableCreateCompanionBuilder =
    LocalSchoolAllergensCompanion Function({
      required String id,
      required String schoolId,
      required String allergenTag,
      Value<int> studentCount,
      Value<String> severityLevel,
      Value<String?> handlingNote,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalSchoolAllergensTableUpdateCompanionBuilder =
    LocalSchoolAllergensCompanion Function({
      Value<String> id,
      Value<String> schoolId,
      Value<String> allergenTag,
      Value<int> studentCount,
      Value<String> severityLevel,
      Value<String?> handlingNote,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalSchoolAllergensTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSchoolAllergensTable> {
  $$LocalSchoolAllergensTableFilterComposer({
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

  ColumnFilters<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allergenTag => $composableBuilder(
    column: $table.allergenTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get studentCount => $composableBuilder(
    column: $table.studentCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get severityLevel => $composableBuilder(
    column: $table.severityLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get handlingNote => $composableBuilder(
    column: $table.handlingNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSchoolAllergensTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSchoolAllergensTable> {
  $$LocalSchoolAllergensTableOrderingComposer({
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

  ColumnOrderings<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allergenTag => $composableBuilder(
    column: $table.allergenTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get studentCount => $composableBuilder(
    column: $table.studentCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get severityLevel => $composableBuilder(
    column: $table.severityLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get handlingNote => $composableBuilder(
    column: $table.handlingNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSchoolAllergensTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSchoolAllergensTable> {
  $$LocalSchoolAllergensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get schoolId =>
      $composableBuilder(column: $table.schoolId, builder: (column) => column);

  GeneratedColumn<String> get allergenTag => $composableBuilder(
    column: $table.allergenTag,
    builder: (column) => column,
  );

  GeneratedColumn<int> get studentCount => $composableBuilder(
    column: $table.studentCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get severityLevel => $composableBuilder(
    column: $table.severityLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get handlingNote => $composableBuilder(
    column: $table.handlingNote,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalSchoolAllergensTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSchoolAllergensTable,
          LocalSchoolAllergen,
          $$LocalSchoolAllergensTableFilterComposer,
          $$LocalSchoolAllergensTableOrderingComposer,
          $$LocalSchoolAllergensTableAnnotationComposer,
          $$LocalSchoolAllergensTableCreateCompanionBuilder,
          $$LocalSchoolAllergensTableUpdateCompanionBuilder,
          (
            LocalSchoolAllergen,
            BaseReferences<
              _$AppDatabase,
              $LocalSchoolAllergensTable,
              LocalSchoolAllergen
            >,
          ),
          LocalSchoolAllergen,
          PrefetchHooks Function()
        > {
  $$LocalSchoolAllergensTableTableManager(
    _$AppDatabase db,
    $LocalSchoolAllergensTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSchoolAllergensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSchoolAllergensTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalSchoolAllergensTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> schoolId = const Value.absent(),
                Value<String> allergenTag = const Value.absent(),
                Value<int> studentCount = const Value.absent(),
                Value<String> severityLevel = const Value.absent(),
                Value<String?> handlingNote = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSchoolAllergensCompanion(
                id: id,
                schoolId: schoolId,
                allergenTag: allergenTag,
                studentCount: studentCount,
                severityLevel: severityLevel,
                handlingNote: handlingNote,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String schoolId,
                required String allergenTag,
                Value<int> studentCount = const Value.absent(),
                Value<String> severityLevel = const Value.absent(),
                Value<String?> handlingNote = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalSchoolAllergensCompanion.insert(
                id: id,
                schoolId: schoolId,
                allergenTag: allergenTag,
                studentCount: studentCount,
                severityLevel: severityLevel,
                handlingNote: handlingNote,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSchoolAllergensTable, LocalSchoolAllergen>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSchoolAllergensTable,
                    LocalSchoolAllergen
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSchoolAllergensTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSchoolAllergensTable,
      LocalSchoolAllergen,
      $$LocalSchoolAllergensTableFilterComposer,
      $$LocalSchoolAllergensTableOrderingComposer,
      $$LocalSchoolAllergensTableAnnotationComposer,
      $$LocalSchoolAllergensTableCreateCompanionBuilder,
      $$LocalSchoolAllergensTableUpdateCompanionBuilder,
      (
        LocalSchoolAllergen,
        BaseReferences<
          _$AppDatabase,
          $LocalSchoolAllergensTable,
          LocalSchoolAllergen
        >,
      ),
      LocalSchoolAllergen,
      PrefetchHooks Function()
    >;
typedef $$LocalTraceabilityDraftsTableCreateCompanionBuilder =
    LocalTraceabilityDraftsCompanion Function({
      required String id,
      required String recordType,
      required String institutionId,
      Value<String?> batchId,
      required String payloadJson,
      Value<bool> isSynced,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalTraceabilityDraftsTableUpdateCompanionBuilder =
    LocalTraceabilityDraftsCompanion Function({
      Value<String> id,
      Value<String> recordType,
      Value<String> institutionId,
      Value<String?> batchId,
      Value<String> payloadJson,
      Value<bool> isSynced,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalTraceabilityDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTraceabilityDraftsTable> {
  $$LocalTraceabilityDraftsTableFilterComposer({
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

  ColumnFilters<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTraceabilityDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTraceabilityDraftsTable> {
  $$LocalTraceabilityDraftsTableOrderingComposer({
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

  ColumnOrderings<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTraceabilityDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTraceabilityDraftsTable> {
  $$LocalTraceabilityDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get institutionId => $composableBuilder(
    column: $table.institutionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get batchId =>
      $composableBuilder(column: $table.batchId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalTraceabilityDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTraceabilityDraftsTable,
          LocalTraceabilityDraft,
          $$LocalTraceabilityDraftsTableFilterComposer,
          $$LocalTraceabilityDraftsTableOrderingComposer,
          $$LocalTraceabilityDraftsTableAnnotationComposer,
          $$LocalTraceabilityDraftsTableCreateCompanionBuilder,
          $$LocalTraceabilityDraftsTableUpdateCompanionBuilder,
          (
            LocalTraceabilityDraft,
            BaseReferences<
              _$AppDatabase,
              $LocalTraceabilityDraftsTable,
              LocalTraceabilityDraft
            >,
          ),
          LocalTraceabilityDraft,
          PrefetchHooks Function()
        > {
  $$LocalTraceabilityDraftsTableTableManager(
    _$AppDatabase db,
    $LocalTraceabilityDraftsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTraceabilityDraftsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalTraceabilityDraftsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalTraceabilityDraftsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recordType = const Value.absent(),
                Value<String> institutionId = const Value.absent(),
                Value<String?> batchId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTraceabilityDraftsCompanion(
                id: id,
                recordType: recordType,
                institutionId: institutionId,
                batchId: batchId,
                payloadJson: payloadJson,
                isSynced: isSynced,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recordType,
                required String institutionId,
                Value<String?> batchId = const Value.absent(),
                required String payloadJson,
                Value<bool> isSynced = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalTraceabilityDraftsCompanion.insert(
                id: id,
                recordType: recordType,
                institutionId: institutionId,
                batchId: batchId,
                payloadJson: payloadJson,
                isSynced: isSynced,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalTraceabilityDraftsTable,
                    LocalTraceabilityDraft
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalTraceabilityDraftsTable,
                    LocalTraceabilityDraft
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTraceabilityDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTraceabilityDraftsTable,
      LocalTraceabilityDraft,
      $$LocalTraceabilityDraftsTableFilterComposer,
      $$LocalTraceabilityDraftsTableOrderingComposer,
      $$LocalTraceabilityDraftsTableAnnotationComposer,
      $$LocalTraceabilityDraftsTableCreateCompanionBuilder,
      $$LocalTraceabilityDraftsTableUpdateCompanionBuilder,
      (
        LocalTraceabilityDraft,
        BaseReferences<
          _$AppDatabase,
          $LocalTraceabilityDraftsTable,
          LocalTraceabilityDraft
        >,
      ),
      LocalTraceabilityDraft,
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
  $$LocalSigningKeysTableTableManager get localSigningKeys =>
      $$LocalSigningKeysTableTableManager(_db, _db.localSigningKeys);
  $$LocalInstitutionMembersTableTableManager get localInstitutionMembers =>
      $$LocalInstitutionMembersTableTableManager(
        _db,
        _db.localInstitutionMembers,
      );
  $$LocalSchoolAllergensTableTableManager get localSchoolAllergens =>
      $$LocalSchoolAllergensTableTableManager(_db, _db.localSchoolAllergens);
  $$LocalTraceabilityDraftsTableTableManager get localTraceabilityDrafts =>
      $$LocalTraceabilityDraftsTableTableManager(
        _db,
        _db.localTraceabilityDrafts,
      );
  $$LocalBmkgCacheTableTableManager get localBmkgCache =>
      $$LocalBmkgCacheTableTableManager(_db, _db.localBmkgCache);
  $$LocalSyncQueueTableTableManager get localSyncQueue =>
      $$LocalSyncQueueTableTableManager(_db, _db.localSyncQueue);
  $$LocalSampleVaultsTableTableManager get localSampleVaults =>
      $$LocalSampleVaultsTableTableManager(_db, _db.localSampleVaults);
}
