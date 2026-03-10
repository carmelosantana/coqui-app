/// A hosted Coqui instance provisioned via the SaaS API.
class HostedInstance {
  final int id;
  final String label;
  final String status;
  final String? subdomain;
  final String? mainIp;
  final int? apiPort;
  final String? apiKey;
  final String? vultrInstanceId;
  final String? region;
  final DateTime createdAt;
  final List<InstanceSnapshot> snapshots;
  final InstanceMetric? latestMetric;

  HostedInstance({
    required this.id,
    required this.label,
    required this.status,
    this.subdomain,
    this.mainIp,
    this.apiPort,
    this.apiKey,
    this.vultrInstanceId,
    this.region,
    required this.createdAt,
    this.snapshots = const [],
    this.latestMetric,
  });

  factory HostedInstance.fromJson(Map<String, dynamic> json) {
    return HostedInstance(
      id: json['id'] as int,
      label: json['label'] as String,
      status: json['status'] as String,
      subdomain: json['subdomain'] as String?,
      mainIp: json['mainIp'] as String?,
      apiPort: json['apiPort'] as int?,
      apiKey: json['apiKey'] as String?,
      vultrInstanceId: json['vultrInstanceId'] as String?,
      region: json['region'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      snapshots: (json['snapshots'] as List?)
              ?.map((s) => InstanceSnapshot.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      latestMetric: json['latestMetric'] != null
          ? InstanceMetric.fromJson(
              json['latestMetric'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isActive => status == 'active';
  bool get isProvisioning => status == 'provisioning' || status == 'installing';
  bool get isStopped => status == 'stopped';
  bool get isError => status == 'error';

  /// Full URL for connecting to this instance.
  String? get url => subdomain != null ? 'https://$subdomain.coqui.bot' : null;

  /// Display-friendly status.
  String get displayStatus => switch (status) {
        'active' => 'Running',
        'provisioning' => 'Provisioning...',
        'installing' => 'Installing...',
        'stopped' => 'Stopped',
        'error' => 'Error',
        'destroying' => 'Destroying...',
        _ => status,
      };
}

/// A backup snapshot for a hosted instance.
class InstanceSnapshot {
  final int id;
  final String? vultrSnapshotId;
  final String? description;
  final String status;
  final int? sizeGb;
  final DateTime createdAt;

  InstanceSnapshot({
    required this.id,
    this.vultrSnapshotId,
    this.description,
    required this.status,
    this.sizeGb,
    required this.createdAt,
  });

  factory InstanceSnapshot.fromJson(Map<String, dynamic> json) {
    return InstanceSnapshot(
      id: json['id'] as int,
      vultrSnapshotId: json['vultrSnapshotId'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String,
      sizeGb: json['sizeGb'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// A metric data point for a hosted instance.
class InstanceMetric {
  final int id;
  final double cpuPercent;
  final double ramPercent;
  final double diskPercent;
  final DateTime recordedAt;

  InstanceMetric({
    required this.id,
    required this.cpuPercent,
    required this.ramPercent,
    required this.diskPercent,
    required this.recordedAt,
  });

  factory InstanceMetric.fromJson(Map<String, dynamic> json) {
    return InstanceMetric(
      id: json['id'] as int,
      cpuPercent: (json['cpuPercent'] as num).toDouble(),
      ramPercent: (json['ramPercent'] as num).toDouble(),
      diskPercent: (json['diskPercent'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }
}
